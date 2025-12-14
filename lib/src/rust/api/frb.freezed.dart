// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'frb.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FrbBook {

 int? get id; String get title; String? get author; String? get isbn; String? get summary; String? get publisher; int? get publicationYear; String? get coverUrl; String? get largeCoverUrl; String? get readingStatus; int? get shelfPosition; int? get userRating; String? get subjects; String? get createdAt; String? get updatedAt; String? get finishedReadingAt; String? get startedReadingAt;
/// Create a copy of FrbBook
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FrbBookCopyWith<FrbBook> get copyWith => _$FrbBookCopyWithImpl<FrbBook>(this as FrbBook, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FrbBook&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.author, author) || other.author == author)&&(identical(other.isbn, isbn) || other.isbn == isbn)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.publisher, publisher) || other.publisher == publisher)&&(identical(other.publicationYear, publicationYear) || other.publicationYear == publicationYear)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.largeCoverUrl, largeCoverUrl) || other.largeCoverUrl == largeCoverUrl)&&(identical(other.readingStatus, readingStatus) || other.readingStatus == readingStatus)&&(identical(other.shelfPosition, shelfPosition) || other.shelfPosition == shelfPosition)&&(identical(other.userRating, userRating) || other.userRating == userRating)&&(identical(other.subjects, subjects) || other.subjects == subjects)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.finishedReadingAt, finishedReadingAt) || other.finishedReadingAt == finishedReadingAt)&&(identical(other.startedReadingAt, startedReadingAt) || other.startedReadingAt == startedReadingAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,title,author,isbn,summary,publisher,publicationYear,coverUrl,largeCoverUrl,readingStatus,shelfPosition,userRating,subjects,createdAt,updatedAt,finishedReadingAt,startedReadingAt);

@override
String toString() {
  return 'FrbBook(id: $id, title: $title, author: $author, isbn: $isbn, summary: $summary, publisher: $publisher, publicationYear: $publicationYear, coverUrl: $coverUrl, largeCoverUrl: $largeCoverUrl, readingStatus: $readingStatus, shelfPosition: $shelfPosition, userRating: $userRating, subjects: $subjects, createdAt: $createdAt, updatedAt: $updatedAt, finishedReadingAt: $finishedReadingAt, startedReadingAt: $startedReadingAt)';
}


}

/// @nodoc
abstract mixin class $FrbBookCopyWith<$Res>  {
  factory $FrbBookCopyWith(FrbBook value, $Res Function(FrbBook) _then) = _$FrbBookCopyWithImpl;
@useResult
$Res call({
 int? id, String title, String? author, String? isbn, String? summary, String? publisher, int? publicationYear, String? coverUrl, String? largeCoverUrl, String? readingStatus, int? shelfPosition, int? userRating, String? subjects, String? createdAt, String? updatedAt, String? finishedReadingAt, String? startedReadingAt
});




}
/// @nodoc
class _$FrbBookCopyWithImpl<$Res>
    implements $FrbBookCopyWith<$Res> {
  _$FrbBookCopyWithImpl(this._self, this._then);

  final FrbBook _self;
  final $Res Function(FrbBook) _then;

/// Create a copy of FrbBook
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? title = null,Object? author = freezed,Object? isbn = freezed,Object? summary = freezed,Object? publisher = freezed,Object? publicationYear = freezed,Object? coverUrl = freezed,Object? largeCoverUrl = freezed,Object? readingStatus = freezed,Object? shelfPosition = freezed,Object? userRating = freezed,Object? subjects = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? finishedReadingAt = freezed,Object? startedReadingAt = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String?,isbn: freezed == isbn ? _self.isbn : isbn // ignore: cast_nullable_to_non_nullable
as String?,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String?,publisher: freezed == publisher ? _self.publisher : publisher // ignore: cast_nullable_to_non_nullable
as String?,publicationYear: freezed == publicationYear ? _self.publicationYear : publicationYear // ignore: cast_nullable_to_non_nullable
as int?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,largeCoverUrl: freezed == largeCoverUrl ? _self.largeCoverUrl : largeCoverUrl // ignore: cast_nullable_to_non_nullable
as String?,readingStatus: freezed == readingStatus ? _self.readingStatus : readingStatus // ignore: cast_nullable_to_non_nullable
as String?,shelfPosition: freezed == shelfPosition ? _self.shelfPosition : shelfPosition // ignore: cast_nullable_to_non_nullable
as int?,userRating: freezed == userRating ? _self.userRating : userRating // ignore: cast_nullable_to_non_nullable
as int?,subjects: freezed == subjects ? _self.subjects : subjects // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,finishedReadingAt: freezed == finishedReadingAt ? _self.finishedReadingAt : finishedReadingAt // ignore: cast_nullable_to_non_nullable
as String?,startedReadingAt: freezed == startedReadingAt ? _self.startedReadingAt : startedReadingAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [FrbBook].
extension FrbBookPatterns on FrbBook {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FrbBook value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FrbBook() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FrbBook value)  $default,){
final _that = this;
switch (_that) {
case _FrbBook():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FrbBook value)?  $default,){
final _that = this;
switch (_that) {
case _FrbBook() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? id,  String title,  String? author,  String? isbn,  String? summary,  String? publisher,  int? publicationYear,  String? coverUrl,  String? largeCoverUrl,  String? readingStatus,  int? shelfPosition,  int? userRating,  String? subjects,  String? createdAt,  String? updatedAt,  String? finishedReadingAt,  String? startedReadingAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FrbBook() when $default != null:
return $default(_that.id,_that.title,_that.author,_that.isbn,_that.summary,_that.publisher,_that.publicationYear,_that.coverUrl,_that.largeCoverUrl,_that.readingStatus,_that.shelfPosition,_that.userRating,_that.subjects,_that.createdAt,_that.updatedAt,_that.finishedReadingAt,_that.startedReadingAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? id,  String title,  String? author,  String? isbn,  String? summary,  String? publisher,  int? publicationYear,  String? coverUrl,  String? largeCoverUrl,  String? readingStatus,  int? shelfPosition,  int? userRating,  String? subjects,  String? createdAt,  String? updatedAt,  String? finishedReadingAt,  String? startedReadingAt)  $default,) {final _that = this;
switch (_that) {
case _FrbBook():
return $default(_that.id,_that.title,_that.author,_that.isbn,_that.summary,_that.publisher,_that.publicationYear,_that.coverUrl,_that.largeCoverUrl,_that.readingStatus,_that.shelfPosition,_that.userRating,_that.subjects,_that.createdAt,_that.updatedAt,_that.finishedReadingAt,_that.startedReadingAt);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? id,  String title,  String? author,  String? isbn,  String? summary,  String? publisher,  int? publicationYear,  String? coverUrl,  String? largeCoverUrl,  String? readingStatus,  int? shelfPosition,  int? userRating,  String? subjects,  String? createdAt,  String? updatedAt,  String? finishedReadingAt,  String? startedReadingAt)?  $default,) {final _that = this;
switch (_that) {
case _FrbBook() when $default != null:
return $default(_that.id,_that.title,_that.author,_that.isbn,_that.summary,_that.publisher,_that.publicationYear,_that.coverUrl,_that.largeCoverUrl,_that.readingStatus,_that.shelfPosition,_that.userRating,_that.subjects,_that.createdAt,_that.updatedAt,_that.finishedReadingAt,_that.startedReadingAt);case _:
  return null;

}
}

}

/// @nodoc


class _FrbBook implements FrbBook {
  const _FrbBook({this.id, required this.title, this.author, this.isbn, this.summary, this.publisher, this.publicationYear, this.coverUrl, this.largeCoverUrl, this.readingStatus, this.shelfPosition, this.userRating, this.subjects, this.createdAt, this.updatedAt, this.finishedReadingAt, this.startedReadingAt});
  

@override final  int? id;
@override final  String title;
@override final  String? author;
@override final  String? isbn;
@override final  String? summary;
@override final  String? publisher;
@override final  int? publicationYear;
@override final  String? coverUrl;
@override final  String? largeCoverUrl;
@override final  String? readingStatus;
@override final  int? shelfPosition;
@override final  int? userRating;
@override final  String? subjects;
@override final  String? createdAt;
@override final  String? updatedAt;
@override final  String? finishedReadingAt;
@override final  String? startedReadingAt;

/// Create a copy of FrbBook
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FrbBookCopyWith<_FrbBook> get copyWith => __$FrbBookCopyWithImpl<_FrbBook>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FrbBook&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.author, author) || other.author == author)&&(identical(other.isbn, isbn) || other.isbn == isbn)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.publisher, publisher) || other.publisher == publisher)&&(identical(other.publicationYear, publicationYear) || other.publicationYear == publicationYear)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.largeCoverUrl, largeCoverUrl) || other.largeCoverUrl == largeCoverUrl)&&(identical(other.readingStatus, readingStatus) || other.readingStatus == readingStatus)&&(identical(other.shelfPosition, shelfPosition) || other.shelfPosition == shelfPosition)&&(identical(other.userRating, userRating) || other.userRating == userRating)&&(identical(other.subjects, subjects) || other.subjects == subjects)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.finishedReadingAt, finishedReadingAt) || other.finishedReadingAt == finishedReadingAt)&&(identical(other.startedReadingAt, startedReadingAt) || other.startedReadingAt == startedReadingAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,title,author,isbn,summary,publisher,publicationYear,coverUrl,largeCoverUrl,readingStatus,shelfPosition,userRating,subjects,createdAt,updatedAt,finishedReadingAt,startedReadingAt);

@override
String toString() {
  return 'FrbBook(id: $id, title: $title, author: $author, isbn: $isbn, summary: $summary, publisher: $publisher, publicationYear: $publicationYear, coverUrl: $coverUrl, largeCoverUrl: $largeCoverUrl, readingStatus: $readingStatus, shelfPosition: $shelfPosition, userRating: $userRating, subjects: $subjects, createdAt: $createdAt, updatedAt: $updatedAt, finishedReadingAt: $finishedReadingAt, startedReadingAt: $startedReadingAt)';
}


}

/// @nodoc
abstract mixin class _$FrbBookCopyWith<$Res> implements $FrbBookCopyWith<$Res> {
  factory _$FrbBookCopyWith(_FrbBook value, $Res Function(_FrbBook) _then) = __$FrbBookCopyWithImpl;
@override @useResult
$Res call({
 int? id, String title, String? author, String? isbn, String? summary, String? publisher, int? publicationYear, String? coverUrl, String? largeCoverUrl, String? readingStatus, int? shelfPosition, int? userRating, String? subjects, String? createdAt, String? updatedAt, String? finishedReadingAt, String? startedReadingAt
});




}
/// @nodoc
class __$FrbBookCopyWithImpl<$Res>
    implements _$FrbBookCopyWith<$Res> {
  __$FrbBookCopyWithImpl(this._self, this._then);

  final _FrbBook _self;
  final $Res Function(_FrbBook) _then;

/// Create a copy of FrbBook
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? title = null,Object? author = freezed,Object? isbn = freezed,Object? summary = freezed,Object? publisher = freezed,Object? publicationYear = freezed,Object? coverUrl = freezed,Object? largeCoverUrl = freezed,Object? readingStatus = freezed,Object? shelfPosition = freezed,Object? userRating = freezed,Object? subjects = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? finishedReadingAt = freezed,Object? startedReadingAt = freezed,}) {
  return _then(_FrbBook(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String?,isbn: freezed == isbn ? _self.isbn : isbn // ignore: cast_nullable_to_non_nullable
as String?,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String?,publisher: freezed == publisher ? _self.publisher : publisher // ignore: cast_nullable_to_non_nullable
as String?,publicationYear: freezed == publicationYear ? _self.publicationYear : publicationYear // ignore: cast_nullable_to_non_nullable
as int?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,largeCoverUrl: freezed == largeCoverUrl ? _self.largeCoverUrl : largeCoverUrl // ignore: cast_nullable_to_non_nullable
as String?,readingStatus: freezed == readingStatus ? _self.readingStatus : readingStatus // ignore: cast_nullable_to_non_nullable
as String?,shelfPosition: freezed == shelfPosition ? _self.shelfPosition : shelfPosition // ignore: cast_nullable_to_non_nullable
as int?,userRating: freezed == userRating ? _self.userRating : userRating // ignore: cast_nullable_to_non_nullable
as int?,subjects: freezed == subjects ? _self.subjects : subjects // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,finishedReadingAt: freezed == finishedReadingAt ? _self.finishedReadingAt : finishedReadingAt // ignore: cast_nullable_to_non_nullable
as String?,startedReadingAt: freezed == startedReadingAt ? _self.startedReadingAt : startedReadingAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$FrbContact {

 int? get id; String get contactType; String get name; String? get firstName; String? get email; String? get phone; String? get address; String? get notes; bool get isActive;
/// Create a copy of FrbContact
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FrbContactCopyWith<FrbContact> get copyWith => _$FrbContactCopyWithImpl<FrbContact>(this as FrbContact, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FrbContact&&(identical(other.id, id) || other.id == id)&&(identical(other.contactType, contactType) || other.contactType == contactType)&&(identical(other.name, name) || other.name == name)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.email, email) || other.email == email)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.address, address) || other.address == address)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.isActive, isActive) || other.isActive == isActive));
}


@override
int get hashCode => Object.hash(runtimeType,id,contactType,name,firstName,email,phone,address,notes,isActive);

@override
String toString() {
  return 'FrbContact(id: $id, contactType: $contactType, name: $name, firstName: $firstName, email: $email, phone: $phone, address: $address, notes: $notes, isActive: $isActive)';
}


}

/// @nodoc
abstract mixin class $FrbContactCopyWith<$Res>  {
  factory $FrbContactCopyWith(FrbContact value, $Res Function(FrbContact) _then) = _$FrbContactCopyWithImpl;
@useResult
$Res call({
 int? id, String contactType, String name, String? firstName, String? email, String? phone, String? address, String? notes, bool isActive
});




}
/// @nodoc
class _$FrbContactCopyWithImpl<$Res>
    implements $FrbContactCopyWith<$Res> {
  _$FrbContactCopyWithImpl(this._self, this._then);

  final FrbContact _self;
  final $Res Function(FrbContact) _then;

/// Create a copy of FrbContact
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? contactType = null,Object? name = null,Object? firstName = freezed,Object? email = freezed,Object? phone = freezed,Object? address = freezed,Object? notes = freezed,Object? isActive = null,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,contactType: null == contactType ? _self.contactType : contactType // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,firstName: freezed == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [FrbContact].
extension FrbContactPatterns on FrbContact {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FrbContact value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FrbContact() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FrbContact value)  $default,){
final _that = this;
switch (_that) {
case _FrbContact():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FrbContact value)?  $default,){
final _that = this;
switch (_that) {
case _FrbContact() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? id,  String contactType,  String name,  String? firstName,  String? email,  String? phone,  String? address,  String? notes,  bool isActive)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FrbContact() when $default != null:
return $default(_that.id,_that.contactType,_that.name,_that.firstName,_that.email,_that.phone,_that.address,_that.notes,_that.isActive);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? id,  String contactType,  String name,  String? firstName,  String? email,  String? phone,  String? address,  String? notes,  bool isActive)  $default,) {final _that = this;
switch (_that) {
case _FrbContact():
return $default(_that.id,_that.contactType,_that.name,_that.firstName,_that.email,_that.phone,_that.address,_that.notes,_that.isActive);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? id,  String contactType,  String name,  String? firstName,  String? email,  String? phone,  String? address,  String? notes,  bool isActive)?  $default,) {final _that = this;
switch (_that) {
case _FrbContact() when $default != null:
return $default(_that.id,_that.contactType,_that.name,_that.firstName,_that.email,_that.phone,_that.address,_that.notes,_that.isActive);case _:
  return null;

}
}

}

/// @nodoc


class _FrbContact implements FrbContact {
  const _FrbContact({this.id, required this.contactType, required this.name, this.firstName, this.email, this.phone, this.address, this.notes, required this.isActive});
  

@override final  int? id;
@override final  String contactType;
@override final  String name;
@override final  String? firstName;
@override final  String? email;
@override final  String? phone;
@override final  String? address;
@override final  String? notes;
@override final  bool isActive;

/// Create a copy of FrbContact
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FrbContactCopyWith<_FrbContact> get copyWith => __$FrbContactCopyWithImpl<_FrbContact>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FrbContact&&(identical(other.id, id) || other.id == id)&&(identical(other.contactType, contactType) || other.contactType == contactType)&&(identical(other.name, name) || other.name == name)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.email, email) || other.email == email)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.address, address) || other.address == address)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.isActive, isActive) || other.isActive == isActive));
}


@override
int get hashCode => Object.hash(runtimeType,id,contactType,name,firstName,email,phone,address,notes,isActive);

@override
String toString() {
  return 'FrbContact(id: $id, contactType: $contactType, name: $name, firstName: $firstName, email: $email, phone: $phone, address: $address, notes: $notes, isActive: $isActive)';
}


}

/// @nodoc
abstract mixin class _$FrbContactCopyWith<$Res> implements $FrbContactCopyWith<$Res> {
  factory _$FrbContactCopyWith(_FrbContact value, $Res Function(_FrbContact) _then) = __$FrbContactCopyWithImpl;
@override @useResult
$Res call({
 int? id, String contactType, String name, String? firstName, String? email, String? phone, String? address, String? notes, bool isActive
});




}
/// @nodoc
class __$FrbContactCopyWithImpl<$Res>
    implements _$FrbContactCopyWith<$Res> {
  __$FrbContactCopyWithImpl(this._self, this._then);

  final _FrbContact _self;
  final $Res Function(_FrbContact) _then;

/// Create a copy of FrbContact
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? contactType = null,Object? name = null,Object? firstName = freezed,Object? email = freezed,Object? phone = freezed,Object? address = freezed,Object? notes = freezed,Object? isActive = null,}) {
  return _then(_FrbContact(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,contactType: null == contactType ? _self.contactType : contactType // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,firstName: freezed == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$FrbLoan {

 int get id; int get copyId; int get contactId; int get libraryId; String get loanDate; String get dueDate; String? get returnDate; String get status; String? get notes; String get contactName; String get bookTitle;
/// Create a copy of FrbLoan
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FrbLoanCopyWith<FrbLoan> get copyWith => _$FrbLoanCopyWithImpl<FrbLoan>(this as FrbLoan, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FrbLoan&&(identical(other.id, id) || other.id == id)&&(identical(other.copyId, copyId) || other.copyId == copyId)&&(identical(other.contactId, contactId) || other.contactId == contactId)&&(identical(other.libraryId, libraryId) || other.libraryId == libraryId)&&(identical(other.loanDate, loanDate) || other.loanDate == loanDate)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.returnDate, returnDate) || other.returnDate == returnDate)&&(identical(other.status, status) || other.status == status)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.contactName, contactName) || other.contactName == contactName)&&(identical(other.bookTitle, bookTitle) || other.bookTitle == bookTitle));
}


@override
int get hashCode => Object.hash(runtimeType,id,copyId,contactId,libraryId,loanDate,dueDate,returnDate,status,notes,contactName,bookTitle);

@override
String toString() {
  return 'FrbLoan(id: $id, copyId: $copyId, contactId: $contactId, libraryId: $libraryId, loanDate: $loanDate, dueDate: $dueDate, returnDate: $returnDate, status: $status, notes: $notes, contactName: $contactName, bookTitle: $bookTitle)';
}


}

/// @nodoc
abstract mixin class $FrbLoanCopyWith<$Res>  {
  factory $FrbLoanCopyWith(FrbLoan value, $Res Function(FrbLoan) _then) = _$FrbLoanCopyWithImpl;
@useResult
$Res call({
 int id, int copyId, int contactId, int libraryId, String loanDate, String dueDate, String? returnDate, String status, String? notes, String contactName, String bookTitle
});




}
/// @nodoc
class _$FrbLoanCopyWithImpl<$Res>
    implements $FrbLoanCopyWith<$Res> {
  _$FrbLoanCopyWithImpl(this._self, this._then);

  final FrbLoan _self;
  final $Res Function(FrbLoan) _then;

/// Create a copy of FrbLoan
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? copyId = null,Object? contactId = null,Object? libraryId = null,Object? loanDate = null,Object? dueDate = null,Object? returnDate = freezed,Object? status = null,Object? notes = freezed,Object? contactName = null,Object? bookTitle = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,copyId: null == copyId ? _self.copyId : copyId // ignore: cast_nullable_to_non_nullable
as int,contactId: null == contactId ? _self.contactId : contactId // ignore: cast_nullable_to_non_nullable
as int,libraryId: null == libraryId ? _self.libraryId : libraryId // ignore: cast_nullable_to_non_nullable
as int,loanDate: null == loanDate ? _self.loanDate : loanDate // ignore: cast_nullable_to_non_nullable
as String,dueDate: null == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as String,returnDate: freezed == returnDate ? _self.returnDate : returnDate // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,contactName: null == contactName ? _self.contactName : contactName // ignore: cast_nullable_to_non_nullable
as String,bookTitle: null == bookTitle ? _self.bookTitle : bookTitle // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [FrbLoan].
extension FrbLoanPatterns on FrbLoan {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FrbLoan value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FrbLoan() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FrbLoan value)  $default,){
final _that = this;
switch (_that) {
case _FrbLoan():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FrbLoan value)?  $default,){
final _that = this;
switch (_that) {
case _FrbLoan() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int copyId,  int contactId,  int libraryId,  String loanDate,  String dueDate,  String? returnDate,  String status,  String? notes,  String contactName,  String bookTitle)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FrbLoan() when $default != null:
return $default(_that.id,_that.copyId,_that.contactId,_that.libraryId,_that.loanDate,_that.dueDate,_that.returnDate,_that.status,_that.notes,_that.contactName,_that.bookTitle);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int copyId,  int contactId,  int libraryId,  String loanDate,  String dueDate,  String? returnDate,  String status,  String? notes,  String contactName,  String bookTitle)  $default,) {final _that = this;
switch (_that) {
case _FrbLoan():
return $default(_that.id,_that.copyId,_that.contactId,_that.libraryId,_that.loanDate,_that.dueDate,_that.returnDate,_that.status,_that.notes,_that.contactName,_that.bookTitle);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int copyId,  int contactId,  int libraryId,  String loanDate,  String dueDate,  String? returnDate,  String status,  String? notes,  String contactName,  String bookTitle)?  $default,) {final _that = this;
switch (_that) {
case _FrbLoan() when $default != null:
return $default(_that.id,_that.copyId,_that.contactId,_that.libraryId,_that.loanDate,_that.dueDate,_that.returnDate,_that.status,_that.notes,_that.contactName,_that.bookTitle);case _:
  return null;

}
}

}

/// @nodoc


class _FrbLoan implements FrbLoan {
  const _FrbLoan({required this.id, required this.copyId, required this.contactId, required this.libraryId, required this.loanDate, required this.dueDate, this.returnDate, required this.status, this.notes, required this.contactName, required this.bookTitle});
  

@override final  int id;
@override final  int copyId;
@override final  int contactId;
@override final  int libraryId;
@override final  String loanDate;
@override final  String dueDate;
@override final  String? returnDate;
@override final  String status;
@override final  String? notes;
@override final  String contactName;
@override final  String bookTitle;

/// Create a copy of FrbLoan
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FrbLoanCopyWith<_FrbLoan> get copyWith => __$FrbLoanCopyWithImpl<_FrbLoan>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FrbLoan&&(identical(other.id, id) || other.id == id)&&(identical(other.copyId, copyId) || other.copyId == copyId)&&(identical(other.contactId, contactId) || other.contactId == contactId)&&(identical(other.libraryId, libraryId) || other.libraryId == libraryId)&&(identical(other.loanDate, loanDate) || other.loanDate == loanDate)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.returnDate, returnDate) || other.returnDate == returnDate)&&(identical(other.status, status) || other.status == status)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.contactName, contactName) || other.contactName == contactName)&&(identical(other.bookTitle, bookTitle) || other.bookTitle == bookTitle));
}


@override
int get hashCode => Object.hash(runtimeType,id,copyId,contactId,libraryId,loanDate,dueDate,returnDate,status,notes,contactName,bookTitle);

@override
String toString() {
  return 'FrbLoan(id: $id, copyId: $copyId, contactId: $contactId, libraryId: $libraryId, loanDate: $loanDate, dueDate: $dueDate, returnDate: $returnDate, status: $status, notes: $notes, contactName: $contactName, bookTitle: $bookTitle)';
}


}

/// @nodoc
abstract mixin class _$FrbLoanCopyWith<$Res> implements $FrbLoanCopyWith<$Res> {
  factory _$FrbLoanCopyWith(_FrbLoan value, $Res Function(_FrbLoan) _then) = __$FrbLoanCopyWithImpl;
@override @useResult
$Res call({
 int id, int copyId, int contactId, int libraryId, String loanDate, String dueDate, String? returnDate, String status, String? notes, String contactName, String bookTitle
});




}
/// @nodoc
class __$FrbLoanCopyWithImpl<$Res>
    implements _$FrbLoanCopyWith<$Res> {
  __$FrbLoanCopyWithImpl(this._self, this._then);

  final _FrbLoan _self;
  final $Res Function(_FrbLoan) _then;

/// Create a copy of FrbLoan
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? copyId = null,Object? contactId = null,Object? libraryId = null,Object? loanDate = null,Object? dueDate = null,Object? returnDate = freezed,Object? status = null,Object? notes = freezed,Object? contactName = null,Object? bookTitle = null,}) {
  return _then(_FrbLoan(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,copyId: null == copyId ? _self.copyId : copyId // ignore: cast_nullable_to_non_nullable
as int,contactId: null == contactId ? _self.contactId : contactId // ignore: cast_nullable_to_non_nullable
as int,libraryId: null == libraryId ? _self.libraryId : libraryId // ignore: cast_nullable_to_non_nullable
as int,loanDate: null == loanDate ? _self.loanDate : loanDate // ignore: cast_nullable_to_non_nullable
as String,dueDate: null == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as String,returnDate: freezed == returnDate ? _self.returnDate : returnDate // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,contactName: null == contactName ? _self.contactName : contactName // ignore: cast_nullable_to_non_nullable
as String,bookTitle: null == bookTitle ? _self.bookTitle : bookTitle // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
