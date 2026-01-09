class CuratedBook {
  final String title;
  final String author;
  final String? isbn;
  final String? coverUrl;

  const CuratedBook({
    required this.title,
    required this.author,
    this.isbn,
    this.coverUrl,
  });
}

class CuratedList {
  final String title;
  final String description;
  final List<CuratedBook> books;
  final String? coverUrl;

  const CuratedList({
    required this.title,
    required this.description,
    required this.books,
    this.coverUrl,
  });
}

/// How to add a new curated list:
/// 1. Create a new `CuratedList` object in the `curatedLists` array below.
/// 2. Provide a `title` and `description` (in French preferred).
/// 3. Add a `coverUrl` (optional) for the list cover.
/// 4. Populate `books` with `CuratedBook` entries. Use ISBN-13 whenever possible to ensure accurate metadata.
///
/// Example:
/// ```dart
/// CuratedList(
///   title: "My New List",
///   description: "A description of this amazing collection.",
///   books: [
///     CuratedBook(title: "Book Title", author: "Author", isbn: "978..."),
///   ],
/// )
/// ```
const List<CuratedList> curatedLists = [
  CuratedList(
    title: "Les 100 livres du siècle (Le Monde)",
    description:
        "Les 100 meilleurs livres du 20ème siècle, selon un sondage réalisé au printemps 1999 par la Fnac et le journal Le Monde.",
    coverUrl: "https://covers.openlibrary.org/b/id/10520666-L.jpg",
    books: [
      CuratedBook(
        title: "L'Étranger",
        author: "Albert Camus",
        isbn: "9782070360024",
      ),
      CuratedBook(
        title: "À la recherche du temps perdu",
        author: "Marcel Proust",
        isbn: "9782070759224",
      ),
      CuratedBook(
        title: "Le Procès",
        author: "Franz Kafka",
        isbn: "9782070368228",
      ),
      CuratedBook(
        title: "Le Petit Prince",
        author: "Antoine de Saint-Exupéry",
        isbn: "9782070612758",
      ),
      CuratedBook(
        title: "La Condition humaine",
        author: "André Malraux",
        isbn: "9782070360024",
      ),
      CuratedBook(
        title: "Voyage au bout de la nuit",
        author: "Louis-Ferdinand Céline",
        isbn: "9782070364886",
      ),
      CuratedBook(
        title: "Les Raisins de la colère",
        author: "John Steinbeck",
        isbn: "9782070360536",
      ),
      CuratedBook(
        title: "Pour qui sonne le glas",
        author: "Ernest Hemingway",
        isbn: "9782070360253",
      ),
      CuratedBook(
        title: "Gatsby le Magnifique",
        author: "F. Scott Fitzgerald",
        isbn: "9782070360451",
      ),
      CuratedBook(
        title: "1984",
        author: "George Orwell",
        isbn: "9782070368228",
      ),
    ],
  ),
  CuratedList(
    title: "Prix Goncourt - Grands classiques",
    description:
        "Sélection de romans ayant remporté le plus prestigieux prix littéraire français.",
    coverUrl: "https://covers.openlibrary.org/b/id/8228691-L.jpg",
    books: [
      CuratedBook(
        title: "L'Amant",
        author: "Marguerite Duras",
        isbn: "9782707306432",
      ),
      CuratedBook(
        title: "Les Bienveillantes",
        author: "Jonathan Littell",
        isbn: "9782070788972",
      ),
      CuratedBook(
        title: "Au revoir là-haut",
        author: "Pierre Lemaitre",
        isbn: "9782253168744",
      ),
      CuratedBook(
        title: "Chanson douce",
        author: "Leïla Slimani",
        isbn: "9782072681578",
      ),
      CuratedBook(
        title: "L'Anomalie",
        author: "Hervé Le Tellier",
        isbn: "9782072887598",
      ),
      CuratedBook(
        title: "Boussole",
        author: "Mathias Énard",
        isbn: "9782330053062",
      ),
      CuratedBook(
        title: "Pas pleurer",
        author: "Lydie Salvayre",
        isbn: "9782021181142",
      ),
      CuratedBook(
        title: "La Carte et le Territoire",
        author: "Michel Houellebecq",
        isbn: "9782290030615",
      ),
    ],
  ),
  CuratedList(
    title: "Classiques de la littérature jeunesse",
    description: "Les incontournables pour les jeunes lecteurs, de 8 à 15 ans.",
    coverUrl: "https://covers.openlibrary.org/b/id/8225138-L.jpg",
    books: [
      CuratedBook(
        title: "Harry Potter à l'école des sorciers",
        author: "J.K. Rowling",
        isbn: "9782070643028",
      ),
      CuratedBook(
        title:
            "Le Monde de Narnia - Le Lion, la Sorcière Blanche et l'Armoire Magique",
        author: "C.S. Lewis",
        isbn: "9782070619023",
      ),
      CuratedBook(
        title: "Charlie et la Chocolaterie",
        author: "Roald Dahl",
        isbn: "9782070601578",
      ),
      CuratedBook(
        title: "Matilda",
        author: "Roald Dahl",
        isbn: "9782070601561",
      ),
      CuratedBook(
        title: "L'Île au trésor",
        author: "Robert Louis Stevenson",
        isbn: "9782070409013",
      ),
      CuratedBook(
        title: "Le Hobbit",
        author: "J.R.R. Tolkien",
        isbn: "9782253049418",
      ),
      CuratedBook(
        title: "Percy Jackson - Le Voleur de foudre",
        author: "Rick Riordan",
        isbn: "9782226326249",
      ),
      CuratedBook(
        title: "Eragon",
        author: "Christopher Paolini",
        isbn: "9782747017510",
      ),
    ],
  ),
  CuratedList(
    title: "Manga essentiels",
    description:
        "Les séries manga incontournables pour débuter ou enrichir sa collection.",
    coverUrl: "https://covers.openlibrary.org/b/id/10521421-L.jpg",
    books: [
      CuratedBook(
        title: "One Piece - Tome 1",
        author: "Eiichiro Oda",
        isbn: "9782723488525",
      ),
      CuratedBook(
        title: "Naruto - Tome 1",
        author: "Masashi Kishimoto",
        isbn: "9782871294658",
      ),
      CuratedBook(
        title: "Death Note - Tome 1",
        author: "Tsugumi Ohba, Takeshi Obata",
        isbn: "9782871294948",
      ),
      CuratedBook(
        title: "L'Attaque des Titans - Tome 1",
        author: "Hajime Isayama",
        isbn: "9782811607203",
      ),
      CuratedBook(
        title: "Fullmetal Alchemist - Tome 1",
        author: "Hiromu Arakawa",
        isbn: "9782351420010",
      ),
      CuratedBook(
        title: "Dragon Ball - Tome 1",
        author: "Akira Toriyama",
        isbn: "9782723418478",
      ),
      CuratedBook(
        title: "My Hero Academia - Tome 1",
        author: "Kohei Horikoshi",
        isbn: "9791032700365",
      ),
      CuratedBook(
        title: "Demon Slayer - Tome 1",
        author: "Koyoharu Gotouge",
        isbn: "9782809465808",
      ),
    ],
  ),
  CuratedList(
    title: "Prix Hugo (Meilleur Roman)",
    description:
        "Romans de science-fiction et de fantasy ayant remporté le prestigieux prix Hugo.",
    coverUrl: "https://covers.openlibrary.org/b/id/8259443-L.jpg",
    books: [
      CuratedBook(
        title: "Dune",
        author: "Frank Herbert",
        isbn: "9782266320481",
      ),
      CuratedBook(
        title: "La Main gauche de la nuit",
        author: "Ursula K. Le Guin",
        isbn: "9782253062831",
      ),
      CuratedBook(
        title: "Neuromancien",
        author: "William Gibson",
        isbn: "9782290312841",
      ),
      CuratedBook(
        title: "La Stratégie Ender",
        author: "Orson Scott Card",
        isbn: "9782290349229",
      ),
      CuratedBook(
        title: "Hypérion",
        author: "Dan Simmons",
        isbn: "9782266241915",
      ),
      CuratedBook(
        title: "American Gods",
        author: "Neil Gaiman",
        isbn: "9782846261562",
      ),
      CuratedBook(
        title: "Le Problème à trois corps",
        author: "Liu Cixin",
        isbn: "9782330077020",
      ),
      CuratedBook(
        title: "La Cinquième Saison",
        author: "N.K. Jemisin",
        isbn: "9782290157183",
      ),
    ],
  ),
  CuratedList(
    title: "Classiques du Cyberpunk",
    description:
        "High tech, low life. Les textes fondateurs du genre cyberpunk.",
    coverUrl: "https://covers.openlibrary.org/b/id/12556533-L.jpg",
    books: [
      CuratedBook(
        title: "Neuromancien",
        author: "William Gibson",
        isbn: "9782290312841",
      ),
      CuratedBook(
        title: "Le Samouraï virtuel",
        author: "Neal Stephenson",
        isbn: "9782253076889",
      ),
      CuratedBook(
        title: "Les androïdes rêvent-ils de moutons électriques ?",
        author: "Philip K. Dick",
        isbn: "9782290349229",
      ),
      CuratedBook(
        title: "Carbone modifié",
        author: "Richard K. Morgan",
        isbn: "9782290004081",
      ),
    ],
  ),
  CuratedList(
    title: "Romans policiers français",
    description:
        "Les maîtres du polar français : suspense, enquêtes et mystères.",
    coverUrl: "https://covers.openlibrary.org/b/id/8701830-L.jpg",
    books: [
      CuratedBook(
        title: "Au revoir là-haut",
        author: "Pierre Lemaitre",
        isbn: "9782253168744",
      ),
      CuratedBook(
        title: "La Vérité sur l'Affaire Harry Quebert",
        author: "Joël Dicker",
        isbn: "9782877068635",
      ),
      CuratedBook(
        title: "Dans les bois éternels",
        author: "Fred Vargas",
        isbn: "9782290019344",
      ),
      CuratedBook(
        title: "Le Parfum",
        author: "Patrick Süskind",
        isbn: "9782253044901",
      ),
      CuratedBook(
        title: "Millénium 1 - Les hommes qui n'aimaient pas les femmes",
        author: "Stieg Larsson",
        isbn: "9782742778430",
      ),
      CuratedBook(
        title: "L'Homme qui voulait vivre sa vie",
        author: "Douglas Kennedy",
        isbn: "9782714437358",
      ),
    ],
  ),
];
