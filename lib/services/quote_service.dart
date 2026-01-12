import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:universal_html/parsing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book.dart';
import '../models/quote.dart';

/// QuoteService with Wikiquote API integration and 24h caching.
///
/// Uses locale-specific Wikiquote endpoints:
/// - fr.wikiquote.org for French
/// - en.wikiquote.org for English
/// - es.wikiquote.org for Spanish
/// - de.wikiquote.org for German
class QuoteService {
  static const String _cacheKeyPrefix = 'quote_cache_v2_';

  // Fallback multilingual quotes (always available offline)
  static final Map<String, List<Quote>> _fallbackQuotes = {
    'en': [
      Quote(
        text: "A room without books is like a body without a soul.",
        author: "Cicero",
        source: "Philosophy",
        locale: 'en',
      ),
      Quote(
        text:
            "The person, be it gentleman or lady, who has not pleasure in a good novel, must be intolerably stupid.",
        author: "Jane Austen",
        source: "Northanger Abbey",
        locale: 'en',
      ),
      Quote(
        text:
            "Good friends, good books, and a sleepy conscience: this is the ideal life.",
        author: "Mark Twain",
        source: "Literature",
        locale: 'en',
      ),
      Quote(
        text: "I have always imagined that Paradise will be a kind of library.",
        author: "Jorge Luis Borges",
        source: "Poem of the Gifts",
        locale: 'en',
      ),
      Quote(
        text: "A book is a dream that you hold in your hand.",
        author: "Neil Gaiman",
        source: "Literature",
        locale: 'en',
      ),
    ],
    'fr': [
      Quote(
        text: "Une pièce sans livres est comme un corps sans âme.",
        author: "Cicéron",
        source: "Philosophie",
        locale: 'fr',
      ),
      Quote(
        text:
            "Lire, c'est boire et manger. L'esprit qui ne lit pas maigrit comme le corps qui ne mange pas.",
        author: "Victor Hugo",
        source: "Littérature",
        locale: 'fr',
      ),
      Quote(
        text: "Le paradis à mon avis est une bibliothèque.",
        author: "Jorge Luis Borges",
        source: "Poème des Dons",
        locale: 'fr',
      ),
      Quote(
        text: "Un livre est un jardin que l'on porte dans sa poche.",
        author: "Proverbe arabe",
        source: "Sagesse",
        locale: 'fr',
      ),
      Quote(
        text: "La lecture est une amitié.",
        author: "Marcel Proust",
        source: "Sur la lecture",
        locale: 'fr',
      ),
    ],
    'es': [
      Quote(
        text: "Una habitación sin libros es como un cuerpo sin alma.",
        author: "Cicerón",
        source: "Filosofía",
        locale: 'es',
      ),
      Quote(
        text: "El que lee mucho y anda mucho, ve mucho y sabe mucho.",
        author: "Miguel de Cervantes",
        source: "Don Quijote",
        locale: 'es',
      ),
      Quote(
        text: "Siempre imaginé que el Paraíso sería algún tipo de biblioteca.",
        author: "Jorge Luis Borges",
        source: "Poema de los Dones",
        locale: 'es',
      ),
      Quote(
        text: "Un libro abierto es un cerebro que habla.",
        author: "Proverbio",
        source: "Sabiduría",
        locale: 'es',
      ),
    ],
    'de': [
      Quote(
        text: "Ein Zimmer ohne Bücher ist wie ein Körper ohne Seele.",
        author: "Cicero",
        source: "Philosophie",
        locale: 'de',
      ),
      Quote(
        text:
            "Ein Buch ist ein Spiegel, in dem wir nur sehen, was wir bereits in uns haben.",
        author: "Carlos Ruiz Zafón",
        source: "Der Schatten des Windes",
        locale: 'de',
      ),
      Quote(
        text:
            "Ich habe mir das Paradies immer als eine Art Bibliothek vorgestellt.",
        author: "Jorge Luis Borges",
        source: "Gedicht der Gaben",
        locale: 'de',
      ),
      Quote(
        text: "Lesen ist Denken mit fremdem Gehirn.",
        author: "Jorge Luis Borges",
        source: "Literatur",
        locale: 'de',
      ),
    ],
  };

  /// Get a quote for the specified locale with caching.
  /// Falls back to English if locale not supported.
  Future<Quote> getQuoteForLocale(String locale) async {
    final normalizedLocale = _normalizeLocale(locale);

    // Try to get from cache first
    final cachedQuote = await _getCachedQuote(normalizedLocale);
    if (cachedQuote != null && !cachedQuote.isExpired) {
      debugPrint('QuoteService: Using cached quote for $normalizedLocale');
      // CRITICAL FIX: Re-clean the cached text to ensure legacy dirty caches are fixed immediately
      // on hot reload/restart without needing to clear app data.
      var (cleanedText, _) = _cleanQuoteText(
        cachedQuote.text,
        normalizedLocale,
      );
      return Quote(
        text: cleanedText,
        author: cachedQuote.author,
        source: cachedQuote.source,
        coverUrl: cachedQuote.coverUrl,
        locale: cachedQuote.locale,
        cachedAt: cachedQuote.cachedAt,
      );
    }

    // Try Wikiquote API
    try {
      final quote = await _fetchFromWikiquote(normalizedLocale);
      if (quote != null) {
        await _cacheQuote(quote, normalizedLocale);
        return quote;
      }
    } catch (e) {
      debugPrint('QuoteService: Wikiquote fetch failed: $e');
    }

    // Fallback to local quotes
    return _getRandomFallback(normalizedLocale);
  }

  /// Legacy method for backward compatibility with dashboard
  Future<Quote?> fetchRandomQuote(
    List<Book> userBooks, {
    String? locale,
  }) async {
    return getQuoteForLocale(locale ?? 'en');
  }

  String _normalizeLocale(String locale) {
    final lang = locale.split('_').first.toLowerCase();
    if (_fallbackQuotes.containsKey(lang)) {
      return lang;
    }
    return 'en';
  }

  Future<Quote?> _getCachedQuote(String locale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix$locale';
      final cachedJson = prefs.getString(cacheKey);

      if (cachedJson != null) {
        final data = json.decode(cachedJson) as Map<String, dynamic>;
        return Quote.fromJson(data);
      }
    } catch (e) {
      debugPrint('QuoteService: Cache read error: $e');
    }
    return null;
  }

  Future<void> _cacheQuote(Quote quote, String locale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix$locale';
      final quoteWithTimestamp = Quote(
        text: quote.text,
        author: quote.author,
        source: quote.source,
        coverUrl: quote.coverUrl,
        locale: locale,
        cachedAt: DateTime.now(),
      );
      await prefs.setString(cacheKey, json.encode(quoteWithTimestamp.toJson()));
      debugPrint('QuoteService: Cached quote for $locale');
    } catch (e) {
      debugPrint('QuoteService: Cache write error: $e');
    }
  }

  /// Fetches the "Quote of the Day" from Wikiquote for the given [locale].
  /// Returns a [Quote] object or null if fetching/parsing fails.
  Future<Quote?> _fetchFromWikiquote(String locale) async {
    // Wikiquote API endpoint varies by language
    final baseUrl = 'https://$locale.wikiquote.org/w/api.php';

    // Quote of the day templates by locale
    final qotdTemplates = {
      'en': 'QoD',
      'fr': 'Citation du jour',
      'es': 'Frase del día',
      'de': 'Zitat des Tages',
    };

    final templateName = qotdTemplates[locale] ?? qotdTemplates['en'];

    try {
      final headers = {
        'User-Agent': 'BiblioGenius/1.0 (contact@bibliogenius.org)',
      };

      // Get the rendered template content via action=parse
      final contentUrl = Uri.parse(
        '$baseUrl?action=parse&format=json&text={{${Uri.encodeComponent(templateName!)}}}&origin=*',
      );

      final contentResponse = await http
          .get(contentUrl, headers: headers)
          .timeout(const Duration(milliseconds: 2500));
      if (contentResponse.statusCode != 200) return null;

      final contentData =
          json.decode(contentResponse.body) as Map<String, dynamic>;
      final parse = contentData['parse'] as Map<String, dynamic>?;
      if (parse == null) return null;

      final htmlContent = parse['text']?['*'] as String?;

      if (htmlContent != null && htmlContent.isNotEmpty) {
        // Parse HTML to extract text
        final doc = parseHtmlDocument(htmlContent);

        // Remove <style> and <script> tags to avoid CSS/JS text being extracted
        doc.querySelectorAll('style, script').forEach((element) {
          element.remove();
        });

        final rawText = doc.body?.text ?? '';

        if (rawText.length > 5) {
          return _parseQuoteFromText(rawText, locale);
        }
      }
    } catch (e) {
      debugPrint('QuoteService: Wikiquote API error: $e');
    }

    return null;
  }

  Quote _parseQuoteFromText(String text, String locale) {
    var (cleaned, author) = _cleanQuoteText(text, locale);

    // Fallback author if empty
    if (author.isEmpty) {
      author = 'Wikiquote';
    }

    return Quote(
      text: cleaned,
      author: author,
      source: 'Wikiquote',
      locale: locale,
    );
  }

  /// Cleans the quote text and tries to extract the author.
  /// Returns a record (quoteText, author).
  (String, String) _cleanQuoteText(String text, String locale) {
    String processed = text.trim();
    String author = '';

    // 1. Specific handling for different locales

    // English: Often uses "~ Author ~" at the end
    if (locale == 'en') {
      final tildeMatch = RegExp(r'~\s*([^~]+)\s*~$').firstMatch(processed);
      if (tildeMatch != null) {
        author = tildeMatch.group(1)?.trim() ?? '';
        processed = processed.substring(0, tildeMatch.start).trim();
      }
    }

    // German: Often "Quote text ... separator Author, Source"
    // Source often follows a comma after Author or newline
    // We try to split by last known separator

    // Common separators across languages
    final separators = ['\n-', '—', '–', '~']; // Em dash, En dash, Tilde

    if (author.isEmpty) {
      for (final sep in separators) {
        final lastIndex = processed.lastIndexOf(sep);
        // Ensure separator is towards the end but not the very end
        if (lastIndex != -1 &&
            lastIndex > 5 &&
            lastIndex < processed.length - 2) {
          // Check if it looks like an author separator
          // (e.g. not just a hyphen in the middle of a sentence)
          // We assume author part is relatively short compared to quote?
          // Or just take the last part.

          final potentialAuthorPart = processed
              .substring(lastIndex + sep.length)
              .trim();

          // If the part after separator is too long, it might be part of the text.
          // Authors usually aren't 200 chars long.
          if (potentialAuthorPart.length < 100) {
            processed = processed.substring(0, lastIndex).trim();
            author = potentialAuthorPart;
            break;
          }
        }
      }
    }

    // If we extracted an author, clean it further (remove source citations if possible)
    if (author.isNotEmpty) {
      // Often author is followed by comma and source (especially DE)
      // e.g. "Friedrich Schiller, An die Freude"
      if (author.contains(',') && locale == 'de') {
        author = author.split(',').first.trim();
      }
      // Remove newlines in author if any
      if (author.contains('\n')) {
        author = author.split('\n').first.trim();
      }
    } else {
      // Fallback: Check if the last line looks like an author
      final lines = processed.split('\n');
      if (lines.length > 1) {
        final lastLine = lines.last.trim();
        // Heuristic: Author lines are usually short and don't end in punctuation like . or !
        // unless it's an initial.
        if (lastLine.length < 50 && !lastLine.endsWith('.')) {
          author = lastLine;
          processed = lines.sublist(0, lines.length - 1).join('\n').trim();
        }
      }
    }

    // 2. Final cleanup of quote text
    // Remove "Citation au hasard" or "Quote of the day" artifacts if present at start
    // (This happens if the parser includes previous/next links text)
    // Basic heuristic: specific known garbage strings
    final garbagePrefixes = [
      'Citation au hasard',
      'Citation du jour',
      'modifier',
      'Frase del día',
      'Zitat des Tages',
    ];
    for (var garbage in garbagePrefixes) {
      if (processed.startsWith(garbage)) {
        processed = processed.substring(garbage.length).trim();
      }
      // Also check if garbage is attached to recent newlines
      processed = processed.replaceAll(garbage, '').trim();
    }

    // Remove specific date-based titles like "Citation du 12 janvier 2026"
    // Regex explanation:
    // ^Citation du : starts with literal
    // .+ : any chars (day, month)
    // (\d{4})? : optional year group
    // \s* : trailing spaces/newlines
    // Replaces just the first match at the start.
    processed = processed
        .replaceAll(RegExp(r'^Citation du .+(\d{4})?\s*'), '')
        .trim();

    // Remove leading/trailing quotes
    processed = processed.replaceAll(RegExp(r'^["«„“]+|["»“]+$'), '').trim();

    return (processed, author);
  }

  Quote _getRandomFallback(String locale) {
    final quotes = _fallbackQuotes[locale] ?? _fallbackQuotes['en']!;
    return quotes[Random().nextInt(quotes.length)];
  }

  /// Clear cached quotes (for testing/debugging)
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_cacheKeyPrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
    debugPrint('QuoteService: Cache cleared');
  }
}
