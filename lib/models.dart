class Review {
  final String user;
  final int rating;
  final String comment;
  final String date;

  Review({
    required this.user,
    required this.rating,
    required this.comment,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'user': user,
        'rating': rating,
        'comment': comment,
        'date': date,
      };

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      user: json['user'] ?? '',
      rating: json['rating'] ?? 0,
      comment: json['comment'] ?? '',
      date: json['date'] ?? '',
    );
  }
}

class Book {
  final String id;
  final String title;
  final String author;
  final String category;
  final String cover;
  bool available;
  final String year;
  final String publisher;
  final String pages;
  final String desc;
  final List<Review> reviews;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    required this.cover,
    required this.available,
    required this.year,
    required this.publisher,
    required this.pages,
    required this.desc,
    required this.reviews,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'category': category,
        'cover': cover,
        'available': available,
        'year': year,
        'publisher': publisher,
        'pages': pages,
        'desc': desc,
        'reviews': reviews.map((r) => r.toJson()).toList(),
      };
}

class EBook {
  final String id;
  final String title;
  final String author;
  final String cover;
  final String readCount;
  final String pages;
  final List<String> chapters;
  final List<String> contents;
  final List<Review> reviews;

  EBook({
    required this.id,
    required this.title,
    required this.author,
    required this.cover,
    required this.readCount,
    required this.pages,
    required this.chapters,
    required this.contents,
    required this.reviews,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'cover': cover,
        'readCount': readCount,
        'pages': pages,
        'chapters': chapters,
        'contents': contents,
        'reviews': reviews.map((r) => r.toJson()).toList(),
      };
}

class Loan {
  final String id;
  final String bookId;
  final String title;
  final String author;
  final String type; // 'Fisik' atau 'Digital'
  final String cover;
  final String dateBorrowed;
  final String dueDate;
  final String pickupMethod;
  String status; // 'Aktif' atau 'Selesai'

  Loan({
    required this.id,
    required this.bookId,
    required this.title,
    required this.author,
    required this.type,
    required this.cover,
    required this.dateBorrowed,
    required this.dueDate,
    required this.pickupMethod,
    required this.status,
  });
}

class Fine {
  final String id;
  final String loanId;
  final String title;
  final int amount;
  final int daysOverdue;
  String status; // 'Belum Bayar' atau 'Lunas'

  Fine({
    required this.id,
    required this.loanId,
    required this.title,
    required this.amount,
    required this.daysOverdue,
    required this.status,
  });
}

class UserNotification {
  final int id;
  final String text;
  final String date;

  UserNotification({
    required this.id,
    required this.text,
    required this.date,
  });
}

class ChatMessage {
  final String text;
  final bool isAi;

  ChatMessage({
    required this.text,
    required this.isAi,
  });
}
