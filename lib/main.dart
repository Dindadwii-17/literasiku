import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'database.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PustakaDigital',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF1D4ED8), // blue-700
        scaffoldBackgroundColor: const Color(0xFFF1F5F9), // slate-100
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1D4ED8),
          brightness: Brightness.light,
          primary: const Color(0xFF1D4ED8),
          secondary: const Color(0xFF4F46E5), // indigo-600
          surface: Colors.white,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF2563EB),
        scaffoldBackgroundColor: const Color(0xFF0F172A), // slate-900
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
          primary: const Color(0xFF2563EB),
          secondary: const Color(0xFF6366F1),
          surface: const Color(0xFF1E293B), // slate-800
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: MainAppContainer(toggleTheme: toggleTheme, themeMode: _themeMode),
    );
  }
}

class MainAppContainer extends StatefulWidget {
  final VoidCallback toggleTheme;
  final ThemeMode themeMode;

  const MainAppContainer({
    super.key,
    required this.toggleTheme,
    required this.themeMode,
  });

  @override
  State<MainAppContainer> createState() => _MainAppContainerState();
}

class _MainAppContainerState extends State<MainAppContainer> {
  // App States
  bool _isGuest = true;
  String _activeTab = 'beranda';
  String _exploreSegment = 'buku'; // 'buku', 'ebook', 'favorit'
  String _exploreCategory = 'semua';
  String _searchQuery = '';
  double _readingProgress = 2.5; // 2.5 of 5 hours
  String _geminiApiKey = ''; // Optional API Key

  // Data States
  late List<Book> _books;
  late List<EBook> _ebooks;
  List<Loan> _loans = [];
  late List<Loan> _history;
  late List<Fine> _fines;
  List<UserNotification> _notifications = [];
  List<String> _wishlist = [];

  // Active Selected IDs
  Book? _selectedBook;
  EBook? _selectedEbook;

  // AI Chat States
  bool _isAiOpen = false;
  final TextEditingController _aiInputController = TextEditingController();
  final ScrollController _aiChatScrollController = ScrollController();
  bool _isAiLoading = false;
  late List<ChatMessage> _chatMessages;

  // Search Controller
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _books = getInitialBooks();
    _ebooks = getInitialEBooks();
    _history = getInitialHistory();
    _fines = getInitialFines();
    _chatMessages = [
      ChatMessage(
        text: 'Halo! Saya PustakaAI, asisten pintar perpustakaan Anda. 🤖✨\n\n'
            'Saya bisa merekomendasikan buku-buku di katalog, memandu cara pinjam/baca, atau membantu menghitung denda keterlambatan Anda. Ada yang bisa dibantu hari ini?',
        isAi: true,
      ),
    ];
  }

  // State Mutators
  void _login(bool guest) {
    setState(() {
      _isGuest = guest;
      _activeTab = 'beranda';
      if (!_isGuest) {
        _showSnackBar('Selamat datang kembali, Riana Safitri!', Colors.green);
      } else {
        _showSnackBar('Masuk sebagai Tamu Perpustakaan', Colors.blue);
      }
    });
  }

  void _logout() {
    setState(() {
      _isGuest = true;
      _activeTab = 'beranda';
      _showSnackBar('Anda telah keluar dari keanggotaan.', Colors.amber);
    });
  }

  void _toggleWishlist(String id) {
    setState(() {
      if (_wishlist.contains(id)) {
        _wishlist.remove(id);
        _showSnackBar('Buku dihapus dari Wishlist.', Colors.amber);
      } else {
        _wishlist.add(id);
        _showSnackBar('Buku ditambahkan ke Wishlist favorit.', Colors.blue);
      }
    });
  }

  void _borrowBook(Book book, String pickupMethod) {
    if (_isGuest) {
      _showSnackBar('Anda harus login sebagai Anggota untuk memesan buku fisik.', Colors.red);
      _showWelcomeOverlay();
      return;
    }

    if (!book.available) {
      _showSnackBar('Buku tidak tersedia untuk dipinjam.', Colors.red);
      return;
    }

    setState(() {
      book.available = false;
      final today = DateTime.now();
      final dueDate = today.add(const Duration(days: 7));

      final months = ["Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Agu", "Sep", "Okt", "Nov", "Des"];
      String formatShortDate(DateTime date) => "${date.day} ${months[date.month - 1]} ${date.year}";

      final newLoan = Loan(
        id: 'loan-${DateTime.now().millisecondsSinceEpoch}',
        bookId: book.id,
        title: book.title,
        author: book.author,
        type: 'Fisik',
        cover: book.cover,
        dateBorrowed: formatShortDate(today),
        dueDate: formatShortDate(dueDate),
        pickupMethod: pickupMethod,
        status: 'Aktif',
      );

      _loans.insert(0, newLoan);
      _notifications.insert(
        0,
        UserNotification(
          id: DateTime.now().millisecondsSinceEpoch,
          text: 'Pesan "${book.title}" berhasil. Metode: $pickupMethod. Buka tiket QR sirkulasi Anda.',
          date: 'Baru saja',
        ),
      );
    });
    _showSnackBar('Berhasil memesan "${book.title}". Ambil via $pickupMethod.', Colors.green);
  }

  void _returnBook(Loan loan) {
    setState(() {
      final book = _books.firstWhere((b) => b.id == loan.bookId);
      book.available = true;
      loan.status = 'Selesai';
      _history.insert(0, loan);
      _loans.removeWhere((l) => l.id == loan.id);
    });
    _showSnackBar('Buku "${loan.title}" telah berhasil dikembalikan.', Colors.green);
  }

  void _payFine(Fine fine, String proofFileName) {
    setState(() {
      fine.status = 'Lunas';
      _fines.removeWhere((f) => f.id == fine.id);
      _notifications.insert(
        0,
        UserNotification(
          id: DateTime.now().millisecondsSinceEpoch,
          text: 'Pembayaran denda dengan lampiran bukti "$proofFileName" berhasil diverifikasi.',
          date: 'Baru saja',
        ),
      );
    });
    _showSnackBar('Pembayaran berhasil diverifikasi. Status akun Anda aktif!', Colors.green);
  }

  void _simulateReadProgress() {
    setState(() {
      _readingProgress += 0.5;
      if (_readingProgress > 5) _readingProgress = 5;
      _notifications.insert(
        0,
        UserNotification(
          id: DateTime.now().millisecondsSinceEpoch,
          text: 'Sesi membaca 30 menit berhasil ditambahkan ke profil Anda. Bagus!',
          date: 'Baru saja',
        ),
      );
    });
    _showSnackBar('Hebat! Progres membaca mingguan Anda bertambah +30 Menit.', Colors.green);
  }

  void _addReview(String id, int rating, String comment) {
    if (_isGuest) {
      _showSnackBar('Hanya anggota terdaftar yang dapat menulis ulasan.', Colors.red);
      return;
    }
    if (rating == 0) {
      _showSnackBar('Harap berikan rating bintang minimal 1 bintang.', Colors.red);
      return;
    }
    if (comment.trim().isEmpty) {
      _showSnackBar('Kolom ulasan komentar tidak boleh kosong.', Colors.red);
      return;
    }

    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final newReview = Review(
      user: 'Riana Safitri',
      rating: rating,
      comment: comment,
      date: todayStr,
    );

    setState(() {
      final book = _books.cast<dynamic>().firstWhere((b) => b.id == id, orElse: () => null) ??
          _ebooks.cast<dynamic>().firstWhere((e) => e.id == id, orElse: () => null);

      if (book != null) {
        book.reviews.insert(0, newReview);
      }
    });

    _showSnackBar('Terima kasih! Ulasan Anda telah diterbitkan.', Colors.green);
  }

  void _showSnackBar(String message, [Color color = Colors.black]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
      ),
    );
  }

  // Obrolan AI Call
  Future<void> _sendAiMessage() async {
    final query = _aiInputController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _chatMessages.add(ChatMessage(text: query, isAi: false));
      _aiInputController.clear();
      _isAiLoading = true;
    });

    _scrollToBottom();

    // Fallback Mock dynamic replies
    String reply = '';
    if (_geminiApiKey.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 1200));
      final qLower = query.toLowerCase();
      if (qLower.contains('fiksi') || qLower.contains('rekomendasi fiksi')) {
        reply = 'Saya sangat merekomendasikan novel **Filosofi Teras** oleh Henry Manampiring (buku fisik pengantar Stoisisme) atau **Gadis Kretek** oleh Ratih Kumala yang kaya akan budaya tembakau nusantara. Keduanya tersedia di perpustakaan kita!';
      } else if (qLower.contains('pinjam') || qLower.contains('cara pinjam')) {
        reply = 'Untuk meminjam buku fisik:\n'
            '1. Cari buku di katalog pada tab Jelajahi.\n'
            '2. Klik **Pinjam Buku** di detail modal.\n'
            '3. Pilih metode pengambilan (Loket Layanan atau Loker Pintar).\n'
            '4. Tunjukkan tiket QR peminjaman di tab Peminjaman ke petugas atau mesin loker.';
      } else if (qLower.contains('teknologi') || qLower.contains('ai') || qLower.contains('komputer')) {
        reply = 'Kami memiliki buku **Kecerdasan Buatan Terapan** oleh Prof. Dr. Ir. Gunawan yang membahas Machine Learning dan Python secara praktis, serta E-Book **Panduan Praktis JavaScript** untuk web developer.';
      } else if (qLower.contains('denda') || qLower.contains('bayar denda')) {
        reply = 'Jika pengembalian terlambat, Anda dikenakan denda **Rp 1.000,- / hari**. Anda dapat melunasinya langsung di tab Denda dengan cara mentransfer dan mengunggah bukti pembayaran.';
      } else {
        reply = 'Tentu! Sebagai asisten **PustakaAI**, saya siap membantu Anda. Anda dapat bertanya tentang rekomendasi buku, panduan peminjaman, atau menanyakan info operasional perpustakaan.';
      }
    } else {
      // Gemini API call
      try {
        final systemInstruction = 'Anda adalah "PustakaAI", asisten pintar berteknologi Gemini di aplikasi PustakaDigital bertema biru safir premium.\n'
            'Tugas utama Anda adalah merekomendasikan buku fisik, e-book, serta menjelaskan manual operasional perpustakaan kepada anggota secara sopan dan informatif.\n\n'
            'Status Pengguna Saat Ini: ${_isGuest ? 'TAMU (PREVIEW MODE)' : 'ANGGOTA TERDAFTAR (RIANA SAFITRI)'}\n'
            'Jika pengguna adalah TAMU: ingatkan dengan sopan fitur pinjam, denda, profil terkunci, dan perlu masuk anggota. E-book terbatas hanya preview bab 1.\n\n'
            'Database Buku: ${jsonEncode(_books.map((b) => b.toJson()).toList())}\n'
            'Database E-Book: ${jsonEncode(_ebooks.map((e) => e.toJson()).toList())}\n\n'
            'Aturan: Gunakan bahasa Indonesia yang ramah. Maksimal 3 paragraf singkat dan gunakan bullet points untuk instruksi.';

        final response = await http.post(
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_geminiApiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': query}
                ]
              }
            ],
            'systemInstruction': {
              'parts': [
                {'text': systemInstruction}
              ]
            }
          }),
        );

        if (response.statusCode == 200) {
          final resData = jsonDecode(response.body);
          reply = resData['candidates']?[0]['content']?['parts']?[0]['text'] ?? 'Maaf, saya tidak mengerti.';
        } else {
          reply = 'Eror API Gemini: ${response.statusCode}. Menggunakan fallback lokal:\n\nMohon maaf, API Key yang dimasukkan tidak valid atau kuota habis.';
        }
      } catch (e) {
        reply = 'Terjadi kesalahan koneksi API. Pastikan internet Anda aktif.';
      }
    }

    setState(() {
      _chatMessages.add(ChatMessage(text: reply, isAi: true));
      _isAiLoading = false;
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_aiChatScrollController.hasClients) {
        _aiChatScrollController.animateTo(
          _aiChatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Modals helpers
  void _showWelcomeOverlay() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Welcome Screen',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return WelcomeOverlay(
          onLogin: (guest) {
            Navigator.pop(context);
            _login(guest);
          },
        );
      },
    );
  }

  void _showBookDetail(dynamic item, String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BookDetailSheet(
          item: item,
          type: type,
          isGuest: _isGuest,
          wishlist: _wishlist,
          onToggleWishlist: _toggleWishlist,
          onBorrow: (pickupMethod) {
            Navigator.pop(context);
            _borrowBook(item as Book, pickupMethod);
          },
          onReadEBook: () {
            Navigator.pop(context);
            _openEBookReader(item as EBook);
          },
          onAddReview: (rating, comment) {
            _addReview(item.id, rating, comment);
          },
          onLoginPrompt: () {
            Navigator.pop(context);
            _showWelcomeOverlay();
          },
        );
      },
    );
  }

  void _openEBookReader(EBook ebook) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      pageBuilder: (context, anim1, anim2) {
        return EBookReaderPage(
          ebook: ebook,
          isGuest: _isGuest,
          onLoginRequired: () {
            Navigator.pop(context);
            _showWelcomeOverlay();
          },
        );
      },
    );
  }

  void _showQRTicket(Loan loan) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tiket Pengambilan QR', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Image.network(
                    'https://placehold.co/150x150/000000/ffffff?text=PICKUP-${loan.id}&font=playfair',
                    width: 150,
                    height: 150,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 150,
                        height: 150,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.qr_code_2, size: 80, color: Colors.blue),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  loan.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Metode: ${loan.pickupMethod}',
                  style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 11),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tunjukkan QR ini ke petugas perpustakaan atau pindai pada mesin loker pintar untuk mengambil buku fisik.',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                  textAlign: TextAlign.center,
                )
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPayFineDialog(Fine fine) {
    showDialog(
      context: context,
      builder: (context) {
        return FinePaymentDialog(
          fine: fine,
          onPayConfirm: (proofFile) {
            _payFine(fine, proofFile);
          },
        );
      },
    );
  }

  void _showEditProfileDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return EditProfileDialog(
          initialName: 'Riana Safitri',
          onSave: (newName) {
            setState(() {
              // Simpan profile name di local variable atau app state
              // Di HTML, appState.user.name diubah
            });
            _showSnackBar('Profil berhasil diperbarui.', Colors.green);
          },
        );
      },
    );
  }

  void _showApiKeySettings() {
    final textController = TextEditingController(text: _geminiApiKey);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pengaturan API Key Gemini', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Masukkan API Key Gemini Anda untuk mengaktifkan kecerdasan chatbot riil. Jika dikosongkan, chatbot akan menggunakan simulasi tanggapan offline.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Gemini API Key',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _geminiApiKey = textController.text.trim();
                });
                Navigator.pop(context);
                _showSnackBar('API Key Gemini berhasil disimpan!', Colors.green);
              },
              child: const Text('Simpan'),
            )
          ],
        );
      },
    );
  }

  // Main UI builder with responsive device frame wrapper
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget mainContent;
    if (_activeTab == 'beranda') {
      mainContent = _buildBeranda();
    } else if (_activeTab == 'jelajahi') {
      mainContent = _buildJelajahi();
    } else if (_activeTab == 'pinjam') {
      mainContent = _isGuest ? _buildLockedScreen('Daftar Sewa') : _buildPeminjaman();
    } else if (_activeTab == 'denda') {
      mainContent = _isGuest ? _buildLockedScreen('Tagihan Keuangan') : _buildDenda();
    } else {
      mainContent = _buildProfil();
    }

    Widget appBody = Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Custom Header Bar
              _buildHeader(isDark),
              // Main Tab Content scrollable
              Expanded(
                child: mainContent,
              ),
            ],
          ),

          // Welcome Quick Screen (Overlay)
          if (_isGuest && _activeTab == 'pinjam') ...[
            // overlay blocker
          ],

          // Floating Action Button for AI Chatbot
          Positioned(
            bottom: 84,
            right: 16,
            child: FloatingActionButton(
              onPressed: () {
                setState(() {
                  _isAiOpen = !_isAiOpen;
                });
              },
              backgroundColor: const Color(0xFF4F46E5), // Indigo
              child: const Icon(Icons.auto_awesome, color: Colors.white),
            ),
          ),

          // Bottom Sheet Chatbot Panel
          if (_isAiOpen) _buildAiChatPanel(isDark),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(isDark),
    );

    return appBody;
  }

  // UI Sections builders
  Widget _buildHeader(bool isDark) {
    final int notifCount = _notifications.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF2563EB), const Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              GestureDetector(
                onTap: () {
                  setState(() {
                    _activeTab = 'profil';
                  });
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                    image: DecorationImage(
                      image: NetworkImage(
                        _isGuest
                            ? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&q=80'
                            : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selamat datang,',
                      style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          _isGuest ? 'Tamu Perpustakaan' : 'Riana Safitri',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: _isGuest ? Colors.amber : Colors.green,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _isGuest ? 'TAMU' : 'ANGGOTA',
                            style: const TextStyle(fontSize: 8, color: Colors.black, fontWeight: FontWeight.bold),
                          ),
                        )
                      ],
                    )
                  ],
                ),
              ),

              // Actions buttons
              IconButton(
                icon: Icon(
                  widget.themeMode == ThemeMode.light ? Icons.dark_mode_outlined : Icons.light_mode,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: widget.toggleTheme,
              ),

              if (_isGuest)
                TextButton.icon(
                  onPressed: _showWelcomeOverlay,
                  icon: const Icon(Icons.login, color: Colors.white, size: 12),
                  label: const Text('Masuk', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),

              // Notification bell button
              PopupMenuButton<String>(
                icon: Stack(
                  children: [
                    const Icon(Icons.notifications_none, color: Colors.white, size: 22),
                    if (notifCount > 0)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                  ],
                ),
                onSelected: (val) {
                  if (val == 'clear') {
                    setState(() {
                      _notifications.clear();
                    });
                    _showSnackBar('Notifikasi dihapus.', Colors.blue);
                  }
                },
                itemBuilder: (BuildContext context) {
                  if (_notifications.isEmpty) {
                    return [
                      const PopupMenuItem(
                        enabled: false,
                        child: Center(
                          child: Text('Belum ada notifikasi baru', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ),
                      )
                    ];
                  }

                  return [
                    PopupMenuItem(
                      enabled: false,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Notifikasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _notifications.clear();
                              });
                              Navigator.pop(context);
                              _showSnackBar('Notifikasi dihapus.', Colors.blue);
                            },
                            child: const Text('Hapus semua', style: TextStyle(fontSize: 10, color: Colors.blue)),
                          )
                        ],
                      ),
                    ),
                    ..._notifications.map(
                      (notif) => PopupMenuItem(
                        enabled: false,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 0.5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(notif.text, style: const TextStyle(fontSize: 10, color: Colors.black87)),
                              const SizedBox(height: 2),
                              Text(notif.date, style: const TextStyle(fontSize: 8, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Dinamis Tab Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _activeTab == 'beranda'
                    ? 'Beranda Pustaka'
                    : _activeTab == 'jelajahi'
                        ? 'Jelajahi Pustaka'
                        : _activeTab == 'pinjam'
                            ? 'Daftar Sewa'
                            : _activeTab == 'denda'
                                ? 'Keuangan'
                                : 'Ruang Anggota',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _activeTab == 'beranda'
                      ? 'Utama'
                      : _activeTab == 'jelajahi'
                          ? (_exploreSegment == 'buku' ? 'Buku Fisik' : (_exploreSegment == 'ebook' ? 'E-Book' : 'Wishlist'))
                          : _activeTab == 'pinjam'
                              ? 'Peminjaman'
                              : _activeTab == 'denda'
                                  ? 'Sanksi & Denda'
                                  : 'Profil & Bantuan',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildBottomNavBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem('beranda', Icons.home_rounded, 'Beranda'),
              _buildNavItem('jelajahi', Icons.explore_rounded, 'Jelajahi'),
              if (!_isGuest) ...[
                _buildNavItem('pinjam', Icons.history_rounded, 'Pinjam', showDot: _loans.isNotEmpty),
                _buildNavItem('denda', Icons.account_balance_wallet_rounded, 'Denda', showDot: _fines.isNotEmpty),
              ],
              _buildNavItem('profil', Icons.person_rounded, 'Profil'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(String tabId, IconData icon, String label, {bool showDot = false}) {
    final bool isSelected = _activeTab == tabId;
    final color = isSelected ? const Color(0xFF1D4ED8) : Colors.grey.shade400;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _activeTab = tabId;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              if (showDot)
                Positioned(
                  top: 0,
                  right: 18,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: tabId == 'denda' ? Colors.red : Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockedScreen(String pageTitle) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline_rounded, size: 64, color: Colors.amber),
            ),
            const SizedBox(height: 24),
            Text(
              '$pageTitle Terkunci',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Akses fitur sirkulasi peminjaman buku fisik, riwayat transaksi, dan rincian denda dibatasi khusus untuk anggota resmi perpustakaan.',
              style: TextStyle(color: Colors.grey, fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showWelcomeOverlay,
              icon: const Icon(Icons.login, size: 14),
              label: const Text('Masuk Akun Anggota'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )
          ],
        ),
      ),
    );
  }

  // TAB 1: BERANDA WIDGETS
  Widget _buildBeranda() {
    final availableBooks = _books.where((b) => b.available).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 800));
        setState(() {});
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Welcome Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PERPUSTAKAAN PINTAR',
                    style: TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Perkaya Pengetahuan\nAnda Tanpa Batas',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, height: 1.2),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Telusuri ribuan koleksi buku fisik dan e-book digital berkualitas di mana saja, kapan saja.',
                    style: const TextStyle(color: Color(0xBFFFFFFF), fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sponsor & Jam info (Tampil hanya jika Tamu)
            if (_isGuest) ...[
              // Banner Sponsor Gramedia
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFF97316), Color(0xFFEF4444)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('PROMO SPONSOR', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 6),
                          const Text('Gramedia Big Sale s.d. 50%!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                          const SizedBox(height: 2),
                          const Text('Gunakan voucher khusus PUSTAKAPINTAR di seluruh outlet terdekat.', style: TextStyle(color: Colors.white70, fontSize: 8.5)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _showSnackBar('Membuka tautan sponsor Gramedia...', Colors.blue),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Beli Buku', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9)),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Operational Card Grid
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E293B)
                      : Colors.blue.shade50.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.blue.shade100.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.blue.shade700, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Informasi Layanan & Jam Operasional',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue.shade800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.2,
                      children: [
                        _buildInfoCard(Icons.access_time_rounded, 'Jam Buka', 'Senin - Sabtu\n08:00 - 20:00 WIB\n(Minggu Libur)'),
                        _buildInfoCard(Icons.pin_drop_rounded, 'Lokasi Utama', 'Gedung Pusat, Lt. 2\nJakarta Selatan'),
                        _buildInfoCard(Icons.phone_rounded, 'Halo Pustaka', 'WhatsApp Service\n+62 812-3456-789'),
                        _buildInfoCard(Icons.calendar_month_rounded, 'Event Terdekat', 'Bedah Filosofi Teras\nSabtu, 14:00 WIB'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Rekomendasi Buku Fisik
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 18),
                    SizedBox(width: 6),
                    Text('Rekomendasi Buku Fisik', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    '${availableBooks.length} Tersedia',
                    style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold, fontSize: 9),
                  ),
                )
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 230,
              child: availableBooks.isEmpty
                  ? const Center(
                      child: Text('Tidak ada rekomendasi buku tersedia.', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: availableBooks.length,
                      itemBuilder: (context, idx) {
                        final book = availableBooks[idx];
                        final bool inWishlist = _wishlist.contains(book.id);

                        return Container(
                          width: 140,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade100),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))
                            ],
                          ),
                          child: InkWell(
                            onTap: () => _showBookDetail(book, 'buku'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      image: DecorationImage(
                                        image: NetworkImage(book.cover),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  book.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  book.author,
                                  style: const TextStyle(color: Colors.grey, fontSize: 9),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      book.category.toUpperCase(),
                                      style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 8),
                                    ),
                                    GestureDetector(
                                      onTap: () => _toggleWishlist(book.id),
                                      child: Icon(
                                        inWishlist ? Icons.favorite : Icons.favorite_border,
                                        color: Colors.red,
                                        size: 14,
                                      ),
                                    )
                                  ],
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 24),

            // Koleksi E-book Populer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tablet_android, color: Colors.indigo, size: 18),
                    SizedBox(width: 6),
                    Text('Daftar E-Book Digital', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _activeTab = 'jelajahi';
                      _exploreSegment = 'ebook';
                    });
                  },
                  child: const Row(
                    children: [
                      Text('Lihat Semua', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                      Icon(Icons.chevron_right, size: 12, color: Colors.blue),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _ebooks.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.65,
              ),
              itemBuilder: (context, idx) {
                final eb = _ebooks[idx];
                final bool inWishlist = _wishlist.contains(eb.id);

                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: InkWell(
                    onTap: () => _showBookDetail(eb, 'ebook'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: NetworkImage(eb.cover),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.remove_red_eye_outlined, size: 8, color: Colors.white),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${eb.readCount} dibaca',
                                        style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          eb.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          eb.author,
                          style: const TextStyle(color: Colors.grey, fontSize: 9),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _openEBookReader(eb),
                                icon: const Icon(Icons.menu_book, size: 10),
                                label: Text(
                                  _isGuest ? 'Pratinjau' : 'Baca',
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4F46E5),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => _toggleWishlist(eb.id),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  inWishlist ? Icons.favorite : Icons.favorite_border,
                                  color: Colors.red,
                                  size: 14,
                                ),
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String title, String desc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 12, color: Colors.blue.shade600),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 8.5)),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.grey, fontSize: 7, height: 1.2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // TAB 2: JELAJAHI
  Widget _buildJelajahi() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter Logic
    List<dynamic> items = [];
    if (_exploreSegment == 'buku') {
      items = _books.where((b) {
        final matchesCat = _exploreCategory == 'semua' || b.category.toLowerCase() == _exploreCategory.toLowerCase();
        final matchesSearch = b.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            b.author.toLowerCase().contains(_searchQuery.toLowerCase());
        return matchesCat && matchesSearch;
      }).toList();
    } else if (_exploreSegment == 'ebook') {
      items = _ebooks.where((eb) {
        final matchesSearch = eb.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            eb.author.toLowerCase().contains(_searchQuery.toLowerCase());
        return matchesSearch;
      }).toList();
    } else {
      // Wishlist items
      final List<dynamic> all = [..._books, ..._ebooks];
      items = all.where((item) => _wishlist.contains(item.id)).toList();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Segmented Control
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildSegmentButton('buku', 'Buku Fisik'),
                _buildSegmentButton('ebook', 'E-Book'),
                _buildSegmentButton('favorit', 'Wishlist (${_wishlist.length})'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Search Bar
          if (_exploreSegment != 'favorit') ...[
            TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Cari judul, penulis, atau genre...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Category Chips (Only shown for Buku Fisik)
          if (_exploreSegment == 'buku') ...[
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildCategoryChip('semua', 'Semua'),
                  _buildCategoryChip('fiksi', 'Fiksi'),
                  _buildCategoryChip('sains', 'Sains & Edu'),
                  _buildCategoryChip('teknologi', 'Teknologi'),
                  _buildCategoryChip('sejarah', 'Sejarah'),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Explore Grid list
          Text(
            _exploreSegment == 'buku'
                ? 'Katalog Buku Fisik'
                : _exploreSegment == 'ebook'
                    ? 'Katalog E-Book Digital'
                    : 'Buku Favorit Saya',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),

          items.isEmpty
              ? Container(
                  height: 200,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.menu_book, size: 40, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text(
                        'Tidak ditemukan buku.',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.65,
                  ),
                  itemBuilder: (context, idx) {
                    final item = items[idx];
                    final bool isEBook = item.id.toString().startsWith('eb');
                    final bool inWishlist = _wishlist.contains(item.id);

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: InkWell(
                        onTap: () => _showBookDetail(item, isEBook ? 'ebook' : 'buku'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      image: DecorationImage(
                                        image: NetworkImage(item.cover),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  if (!isEBook)
                                    Positioned(
                                      top: 6,
                                      left: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: item.available ? Colors.blue : Colors.red,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.available ? 'Tersedia' : 'Disewa',
                                          style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    )
                                  else
                                    Positioned(
                                      bottom: 6,
                                      left: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${item.readCount} baca',
                                          style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.star, size: 8, color: Colors.amber),
                                          const SizedBox(width: 2),
                                          Text(
                                            getAverageRating(item.reviews),
                                            style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                                          )
                                        ],
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.author,
                              style: const TextStyle(color: Colors.grey, fontSize: 9),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isEBook ? 'E-BOOK' : item.category.toUpperCase(),
                                    style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 7.5),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _toggleWishlist(item.id),
                                  child: Icon(
                                    inWishlist ? Icons.favorite : Icons.favorite_border,
                                    color: Colors.red,
                                    size: 14,
                                  ),
                                )
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(String id, String label) {
    final bool isSelected = _exploreSegment == id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _exploreSegment = id;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF334155) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 3,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: Alignment.center.x == 0 ? TextAlign.center : null,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? (isDark ? Colors.white : const Color(0xFF1E293B))
                  : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String catId, String label) {
    final bool isSelected = _exploreCategory == catId;
    return GestureDetector(
      onTap: () => filterCategory(catId),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1D4ED8) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  void filterCategory(String catId) {
    setState(() {
      _exploreCategory = catId;
    });
  }

  // TAB 3: PEMINJAMAN
  String _loanSubTab = 'aktif';

  Widget _buildPeminjaman() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayLoans = _loanSubTab == 'aktif' ? _loans : _history;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _loanSubTab = 'aktif'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _loanSubTab == 'aktif'
                            ? (isDark ? const Color(0xFF334155) : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Peminjaman Aktif',
                        textAlign: Alignment.center.x == 0 ? TextAlign.center : null,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _loanSubTab == 'aktif' ? (isDark ? Colors.white : Colors.black87) : Colors.grey),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _loanSubTab = 'riwayat'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _loanSubTab == 'riwayat'
                            ? (isDark ? const Color(0xFF334155) : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Riwayat Selesai',
                        textAlign: Alignment.center.x == 0 ? TextAlign.center : null,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _loanSubTab == 'riwayat' ? (isDark ? Colors.white : Colors.black87) : Colors.grey),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          displayLoans.isEmpty
              ? Container(
                  height: 200,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open_rounded, size: 40, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Text(
                        _loanSubTab == 'aktif' ? 'Tidak ada peminjaman aktif saat ini.' : 'Belum ada riwayat pengembalian.',
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayLoans.length,
                  itemBuilder: (context, idx) {
                    final loan = displayLoans[idx];

                    if (_loanSubTab == 'aktif') {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(loan.cover, width: 48, height: 64, fit: BoxFit.cover),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                                        child: Text(loan.type.toUpperCase(), style: TextStyle(color: Colors.blue.shade700, fontSize: 7, fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(4)),
                                        child: Text(loan.pickupMethod.toUpperCase(), style: TextStyle(color: Colors.indigo.shade700, fontSize: 7, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(loan.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  Text('Jatuh Tempo: ${loan.dueDate}', style: const TextStyle(color: Colors.grey, fontSize: 9)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _showQRTicket(loan),
                                  icon: const Icon(Icons.qr_code_2, size: 10),
                                  label: const Text('Tiket QR', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1D4ED8),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextButton(
                                  onPressed: () => _returnBook(loan),
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.red.shade50,
                                    foregroundColor: Colors.red,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Kembalikan', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold)),
                                )
                              ],
                            )
                          ],
                        ),
                      );
                    } else {
                      // Riwayat Selesai UI
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                                  child: const Text('FISIK', style: TextStyle(color: Colors.grey, fontSize: 7, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(height: 4),
                                Text(loan.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                                const SizedBox(height: 2),
                                Text('Dipinjam: ${loan.dateBorrowed} • Kembali: ${loan.dueDate}', style: const TextStyle(color: Colors.grey, fontSize: 8.5)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, size: 10, color: Colors.blue.shade700),
                                  const SizedBox(width: 4),
                                  Text('Selesai', style: TextStyle(color: Colors.blue.shade700, fontSize: 9, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    }
                  },
                )
        ],
      ),
    );
  }

  // TAB 4: DENDA
  Widget _buildDenda() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int totalDenda = 0;
    for (var f in _fines) {
      if (f.status == 'Belum Bayar') totalDenda += f.amount;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFD97706)]),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.red.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Tagihan Denda', style: TextStyle(color: Colors.white70, fontSize: 10)),
                const SizedBox(height: 4),
                Text(
                  'Rp ${totalDenda.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
                  child: const Row(
                    children: [
                      Icon(Icons.info, size: 12, color: Colors.white),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Denda dihitung Rp 1.000 / hari keterlambatan pengembalian buku.',
                          style: TextStyle(color: Colors.white70, fontSize: 8),
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text('Rincian Keterlambatan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 12),

          _fines.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 36, color: Colors.blue),
                      SizedBox(height: 8),
                      Text('Bebas Tunggakan Denda', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      Text('Semua denda Anda lunas dan bersih!', style: TextStyle(color: Colors.grey, fontSize: 9)),
                    ],
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _fines.length,
                  itemBuilder: (context, idx) {
                    final fine = _fines[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                                child: Text('TERLAMBAT ${fine.daysOverdue} HARI', style: const TextStyle(color: Colors.red, fontSize: 7, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(height: 4),
                              Text(fine.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 2),
                              Text('Tagihan: Rp ${fine.amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: () => _showPayFineDialog(fine),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1D4ED8),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Bayar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                          )
                        ],
                      ),
                    );
                  },
                )
        ],
      ),
    );
  }

  // TAB 5: PROFIL WIDGETS
  Widget _buildProfil() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Locked Card (Tamu) vs Digital Member Card (Anggota)
          if (_isGuest)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  const Icon(Icons.lock_person, size: 40, color: Colors.amber),
                  const SizedBox(height: 12),
                  const Text('Kartu Anggota Terkunci', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  const Text('Daftar atau masuk sebagai anggota untuk mendapatkan QR-ID perpustakaan digital resmi Anda.', style: TextStyle(color: Colors.grey, fontSize: 10), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showWelcomeOverlay,
                    icon: const Icon(Icons.login, size: 12),
                    label: const Text('Masuk Anggota', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      foregroundColor: Colors.white,
                    ),
                  )
                ],
              ),
            )
          else ...[
            // Digital Member Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF172554)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade800),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                        child: const Text('KARTU ANGGOTA DIGITAL', style: TextStyle(color: Colors.blue, fontSize: 7, fontWeight: FontWeight.bold)),
                      ),
                      const Icon(Icons.school, color: Colors.blue, size: 24),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Riana Safitri', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 2),
                  const Text('ID Anggota: LIB-2026-8942', style: TextStyle(color: Colors.white70, fontSize: 10)),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MASA BERLAKU', style: TextStyle(color: Colors.white30, fontSize: 7)),
                          Text('Desember 2028', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.barcode_reader, size: 20, color: Colors.black),
                      )
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stat counters
            Row(
              children: [
                _buildStatBox('Dibaca', '${_history.length + 11}'),
                const SizedBox(width: 8),
                _buildStatBox('Sedang Pinjam', '${_loans.length}', color: Colors.blue),
                const SizedBox(width: 8),
                _buildStatBox('Denda', '${_fines.length}', color: Colors.red),
              ],
            ),
            const SizedBox(height: 20),

            // Reading Progress Gamification Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.alarm, size: 16, color: Colors.blue),
                          SizedBox(width: 6),
                          Text('Target Membaca Mingguan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        ],
                      ),
                      Text(
                        '$_readingProgress / 5 Jam',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _readingProgress / 5,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Minat Baca: Tinggi 🔥', style: TextStyle(color: Colors.grey, fontSize: 9)),
                      TextButton.icon(
                        onPressed: _simulateReadProgress,
                        icon: const Icon(Icons.add_circle_outline, size: 12),
                        label: const Text('Baca 30 Menit', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(foregroundColor: Colors.blue, padding: EdgeInsets.zero),
                      )
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Panduan FAQ Accordion
          const Row(
            children: [
              Icon(Icons.help_outline, color: Colors.blue, size: 18),
              SizedBox(width: 6),
              Text('Panduan & Manual Penggunaan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          _buildFAQAccordion('Bagaimana cara meminjam buku fisik?',
              '1. Cari buku fisik di halaman utama (Katalog Buku).\n'
              '2. Tekan buku untuk detail lengkap dan klik **Pinjam Buku**.\n'
              '3. Pilih metode pengambilan (Loket atau Loker Pintar).\n'
              '4. Tunjukkan Tiket QR Peminjaman Anda di tab Peminjaman untuk diverifikasi oleh staf atau mesin loker.'),
          const SizedBox(height: 8),
          _buildFAQAccordion('Bagaimana cara membaca E-Book gratis?',
              'Pilih menu E-Book pada navigasi bawah, cari e-book yang Anda minati, lalu klik **Baca Sekarang**. Mode tamu mendapatkan batas pratinjau (Bab 1), silakan login anggota untuk bebas membaca utuh tanpa limit.'),
          const SizedBox(height: 8),
          _buildFAQAccordion('Berapa tarif denda keterlambatan?',
              'Denda dihitung senilai **Rp 1.000,- / hari keterlambatan** dari batas tanggal jatuh tempo. Anda dapat melakukan pembayaran via transfer bank lalu melampirkan bukti transfer secara langsung di tab Denda.'),

          // Profile Actions (Logout/Edit)
          if (!_isGuest) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showEditProfileDialog,
                icon: const Icon(Icons.edit_note, size: 14),
                label: const Text('Ubah Profil Anggota', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, size: 14),
                label: const Text('Keluar Akun', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildStatBox(String title, String val, {Color color = Colors.black}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 8.5)),
            const SizedBox(height: 4),
            Text(
              val,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color == Colors.black ? (isDark ? Colors.white : Colors.black87) : color,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFAQAccordion(String question, String answer) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(question, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(answer, style: const TextStyle(color: Colors.grey, fontSize: 10, height: 1.4)),
          )
        ],
      ),
    );
  }

  // FLOATING AI CHAT SHEET
  Widget _buildAiChatPanel(bool isDark) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      top: 100,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, -5),
            )
          ],
        ),
        child: Column(
          children: [
            // AI Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)]),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.android, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('PustakaAI Assistant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          Row(
                            children: [
                              Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              const Text('Gemini 1.5 Flash Aktif', style: TextStyle(color: Colors.white70, fontSize: 8)),
                            ],
                          )
                        ],
                      )
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white, size: 18),
                        onPressed: _showApiKeySettings,
                      ),
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _isAiOpen = false;
                          });
                        },
                      ),
                    ],
                  )
                ],
              ),
            ),

            // Messages History
            Expanded(
              child: ListView.builder(
                controller: _aiChatScrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _chatMessages.length,
                itemBuilder: (context, idx) {
                  final msg = _chatMessages[idx];
                  return Align(
                    alignment: msg.isAi ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: msg.isAi
                            ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                            : const Color(0xFF1D4ED8),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: msg.isAi ? Radius.zero : const Radius.circular(16),
                          bottomRight: msg.isAi ? const Radius.circular(16) : Radius.zero,
                        ),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 4, offset: const Offset(0, 1))
                        ],
                      ),
                      child: Text(
                        msg.text,
                        style: TextStyle(
                          color: msg.isAi ? (isDark ? Colors.white70 : Colors.black87) : Colors.white,
                          fontSize: 10.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            if (_isAiLoading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 8),
                    Text('PustakaAI sedang berpikir...', style: TextStyle(color: Colors.grey.shade400, fontSize: 9)),
                  ],
                ),
              ),

            // Input obrolan
            Container(
              padding: const EdgeInsets.all(10),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _aiInputController,
                      style: const TextStyle(fontSize: 11),
                      decoration: InputDecoration(
                        hintText: 'Tanyakan sesuatu...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                      ),
                      onSubmitted: (_) => _sendAiMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendAiMessage,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)]),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send, color: Colors.white, size: 14),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // Helpers
  String getAverageRating(List<Review> reviews) {
    if (reviews.isEmpty) return '0.0';
    final sum = reviews.fold<int>(0, (acc, r) => acc + r.rating);
    return (sum / reviews.length).toStringAsFixed(1);
  }
}

// WELCOME OVERLAY
class WelcomeOverlay extends StatelessWidget {
  final Function(bool) onLogin;

  const WelcomeOverlay({super.key, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF312E81), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 10))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.bookmark_outline, size: 48, color: Colors.blue),
              ),
              const SizedBox(height: 16),
              const Text('PustakaDigital', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
              const Text('Pintu Gerbang Pengetahuan dalam Genggaman', style: TextStyle(color: Colors.blue, fontSize: 9.5), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                child: const Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 12, color: Colors.blue),
                        SizedBox(width: 4),
                        Text('Akses Anggota Penuh', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 9.5)),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Dengan masuk sebagai anggota resmi, Anda dapat menikmati fitur peminjaman buku fisik, bebas denda keterlambatan, akses baca utuh seluruh E-Book, serta berpartisipasi memberikan rating ulasan.',
                      style: TextStyle(color: Colors.white70, fontSize: 8.5, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => onLogin(false),
                  icon: const Icon(Icons.how_to_reg, size: 14),
                  label: const Text('Masuk sebagai Anggota', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => onLogin(true),
                  icon: const Icon(Icons.visibility_outlined, size: 14),
                  label: const Text('Tetap dalam Mode Tamu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white30),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// BOOK DETAIL SHEET
class BookDetailSheet extends StatefulWidget {
  final dynamic item;
  final String type;
  final bool isGuest;
  final List<String> wishlist;
  final Function(String) onToggleWishlist;
  final Function(String) onBorrow;
  final VoidCallback onReadEBook;
  final Function(int, String) onAddReview;
  final VoidCallback onLoginPrompt;

  const BookDetailSheet({
    super.key,
    required this.item,
    required this.type,
    required this.isGuest,
    required this.wishlist,
    required this.onToggleWishlist,
    required this.onBorrow,
    required this.onReadEBook,
    required this.onAddReview,
    required this.onLoginPrompt,
  });

  @override
  State<BookDetailSheet> createState() => _BookDetailSheetState();
}

class _BookDetailSheetState extends State<BookDetailSheet> {
  String _pickupMethod = 'Loket Pelayanan';
  int _activeReviewStars = 0;
  final TextEditingController _reviewController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = widget.item;
    final bool isEbook = widget.type == 'ebook';
    final bool inWishlist = widget.wishlist.contains(item.id);

    double screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover and Header info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(item.cover, width: 100, height: 140, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                isEbook ? 'E-BOOK' : item.category.toUpperCase(),
                                style: TextStyle(color: Colors.blue.shade800, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text('Oleh: ${item.author}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Row(
                                  children: List.generate(5, (idx) {
                                    final ratingVal = double.tryParse(getAverageRating(item.reviews)) ?? 0;
                                    return Icon(
                                      idx < ratingVal.floor() ? Icons.star : Icons.star_border,
                                      color: Colors.amber,
                                      size: 14,
                                    );
                                  }),
                                ),
                                const SizedBox(width: 6),
                                Text(getAverageRating(item.reviews), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                const SizedBox(width: 4),
                                Text('(${item.reviews.length} Ulasan)', style: const TextStyle(color: Colors.grey, fontSize: 9.5)),
                              ],
                            )
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(inWishlist ? Icons.favorite : Icons.favorite_border, color: Colors.red),
                        onPressed: () {
                          widget.onToggleWishlist(item.id);
                          setState(() {});
                        },
                      )
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Info grid publisher/year/pages
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSpecItem('Penerbit', item is Book ? item.publisher : 'Pustaka Digital'),
                        _buildSpecItem('Tahun', item is Book ? item.year : '2023'),
                        _buildSpecItem('Tebal', item.pages),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Pickup methods selection for physical books
                  if (!isEbook && !widget.isGuest && item.available) ...[
                    const Text('Metode Pengambilan Buku', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildPickupOption('Loket Pelayanan')),
                        const SizedBox(width: 10),
                        Expanded(child: _buildPickupOption('Loker Pintar Mandiri')),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Synopsis
                  const Text('Sinopsis', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
                  const SizedBox(height: 6),
                  Text(
                    item.desc,
                    style: const TextStyle(color: Colors.grey, fontSize: 10.5, height: 1.4),
                    textAlign: TextAlign.justify,
                  ),
                  const SizedBox(height: 24),

                  // Reviews List
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Ulasan Pembaca', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
                      const Icon(Icons.comment_bank_outlined, color: Colors.grey, size: 16),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildReviewsList(item.reviews),
                  const SizedBox(height: 20),

                  // Review submission form
                  if (widget.isGuest)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        children: [
                          const Text('Anda harus masuk sebagai anggota untuk memberikan rating bintang & ulasan.', style: TextStyle(fontSize: 10, color: Colors.amber), textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: widget.onLoginPrompt,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                            child: const Text('Masuk Akun Anggota', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white)),
                          )
                        ],
                      ),
                    )
                  else ...[
                    const Text('Tulis Ulasan Anda', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Rating:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        const SizedBox(width: 8),
                        Row(
                          children: List.generate(5, (idx) {
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _activeReviewStars = idx + 1;
                                });
                              },
                              child: Icon(
                                idx < _activeReviewStars ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                                size: 20,
                              ),
                            );
                          }),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _reviewController,
                      style: const TextStyle(fontSize: 10.5),
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Tuliskan pendapat Anda mengenai buku ini...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(10),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          widget.onAddReview(_activeReviewStars, _reviewController.text);
                          setState(() {
                            _activeReviewStars = 0;
                            _reviewController.clear();
                          });
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4ED8), foregroundColor: Colors.white),
                        child: const Text('Kirim Ulasan', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ]
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!isEbook)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: item.available ? Colors.blue.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item.available ? 'Tersedia' : 'Sedang Dipinjam',
                      style: TextStyle(color: item.available ? Colors.blue : Colors.red, fontSize: 9.5, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  const SizedBox(),
                ElevatedButton(
                  onPressed: isEbook
                      ? widget.onReadEBook
                      : (item.available ? () => widget.onBorrow(_pickupMethod) : null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEbook ? const Color(0xFF4F46E5) : const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    isEbook ? (widget.isGuest ? 'Pratinjau E-Book' : 'Baca Sekarang') : (widget.isGuest ? 'Sewa (Login)' : 'Pinjam Buku'),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSpecItem(String title, String val) {
    return Column(
      children: [
        Text(title.toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 7.5)),
        const SizedBox(height: 2),
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5)),
      ],
    );
  }

  Widget _buildPickupOption(String method) {
    final bool isSelected = _pickupMethod == method;
    return GestureDetector(
      onTap: () {
        setState(() {
          _pickupMethod = method;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(color: isSelected ? Colors.blue : Colors.grey.shade300, width: 1.5),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? Colors.blue.shade50.withOpacity(0.2) : Colors.transparent,
        ),
        child: Center(
          child: Text(
            method == 'Loket Pelayanan' ? 'Loket Layanan' : 'Loker Pintar QR',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9.5, color: isSelected ? Colors.blue : Colors.grey.shade700),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewsList(List<Review> reviews) {
    if (reviews.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text('Belum ada ulasan untuk buku ini. Jadilah yang pertama!', style: TextStyle(color: Colors.grey, fontSize: 9.5)),
      );
    }

    return Column(
      children: reviews.map((rev) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50.withOpacity(0.5),
            border: Border.all(color: Colors.grey.shade100),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(rev.user, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9.5)),
                  Text(rev.date, style: const TextStyle(color: Colors.grey, fontSize: 8)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: List.generate(5, (idx) {
                  return Icon(
                    idx < rev.rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 10,
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(rev.comment, style: const TextStyle(color: Colors.black87, fontSize: 9, height: 1.3)),
            ],
          ),
        );
      }).toList(),
    );
  }

  String getAverageRating(List<Review> reviews) {
    if (reviews.isEmpty) return '0.0';
    final sum = reviews.fold<int>(0, (acc, r) => acc + r.rating);
    return (sum / reviews.length).toStringAsFixed(1);
  }
}

// EBOOK READER INTERFACE
class EBookReaderPage extends StatefulWidget {
  final EBook ebook;
  final bool isGuest;
  final VoidCallback onLoginRequired;

  const EBookReaderPage({
    super.key,
    required this.ebook,
    required this.isGuest,
    required this.onLoginRequired,
  });

  @override
  State<EBookReaderPage> createState() => _EBookReaderPageState();
}

class _EBookReaderPageState extends State<EBookReaderPage> {
  int _chapterIndex = 0;
  double _fontSize = 14;
  String _theme = 'light'; // 'light', 'sepia', 'dark'

  @override
  Widget build(BuildContext context) {
    final ebook = widget.ebook;
    final isLocked = widget.isGuest && _chapterIndex > 0;

    // Theme values
    Color bg;
    Color textCol;
    Color appBarBg;
    if (_theme == 'sepia') {
      bg = const Color(0xFFF4ECD8);
      textCol = const Color(0xFF5B4636);
      appBarBg = const Color(0xFFF4ECD8);
    } else if (_theme == 'dark') {
      bg = const Color(0xFF0F172A);
      textCol = const Color(0xFFE2E8F0);
      appBarBg = const Color(0xFF1E293B);
    } else {
      bg = Colors.white;
      textCol = const Color(0xFF334155);
      appBarBg = Colors.white;
    }

    final double progress = ((_chapterIndex + 1) / ebook.chapters.length) * 100;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text('Membaca E-Book', style: TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.bold)),
            Text(ebook.title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: Alignment.center.x == 0,
        actions: [
          IconButton(icon: const Icon(Icons.remove, size: 16), onPressed: () => setState(() => _fontSize = _fontSize > 10 ? _fontSize - 2 : 10)),
          IconButton(icon: const Icon(Icons.add, size: 16), onPressed: () => setState(() => _fontSize = _fontSize < 24 ? _fontSize + 2 : 24)),
          IconButton(
            icon: Icon(_theme == 'light'
                ? Icons.coffee_outlined
                : _theme == 'sepia'
                    ? Icons.dark_mode_outlined
                    : Icons.wb_sunny_outlined),
            onPressed: () {
              setState(() {
                if (_theme == 'light') {
                  _theme = 'sepia';
                } else if (_theme == 'sepia') {
                  _theme = 'dark';
                } else {
                  _theme = 'light';
                }
              });
            },
          )
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ebook.chapters[_chapterIndex],
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textCol),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isLocked
                        ? 'Kreativitas tingkat lanjut membutuhkan teknik eksplorasi pikiran mendalam. Pada halaman kedua ini, kita akan membahas cara menghubungkan...'
                        : ebook.contents[_chapterIndex],
                    style: TextStyle(fontSize: _fontSize, color: textCol, height: 1.5),
                    textAlign: TextAlign.justify,
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // Lock overlay for guest
          if (isLocked)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      bg.withOpacity(0.0),
                      bg.withOpacity(0.95),
                      bg,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.4, 0.7],
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 300,
                    margin: const EdgeInsets.only(top: 80),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _theme == 'dark' ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)
                      ],
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_clock_outlined, size: 40, color: Colors.indigo),
                        const SizedBox(height: 12),
                        const Text('Batas Pratinjau Terbuka!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 6),
                        const Text('Anda telah mencapai batas 1 halaman gratis mode preview. Silakan masuk sebagai Anggota untuk membaca seluruh koleksi E-Book secara gratis tanpa batas.', style: TextStyle(color: Colors.grey, fontSize: 9.5), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: widget.onLoginRequired,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
                          child: const Text('Masuk Akun Anggota', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: appBarBg,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Selesai membaca: ${progress.round()}%', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ElevatedButton(
              onPressed: () {
                if (widget.isGuest && _chapterIndex == 0) {
                  setState(() {
                    _chapterIndex = 1;
                  });
                  return;
                }
                if (isLocked) return;

                if (_chapterIndex < ebook.chapters.length - 1) {
                  setState(() {
                    _chapterIndex++;
                  });
                } else {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hebat! Anda telah menyelesaikan seluruh bab E-book ini.')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isLocked ? Colors.grey : const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(
                _chapterIndex < ebook.chapters.length - 1 ? 'Lanjut' : 'Selesai',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// FINE PAYMENT DIALOG
class FinePaymentDialog extends StatefulWidget {
  final Fine fine;
  final Function(String) onPayConfirm;

  const FinePaymentDialog({super.key, required this.fine, required this.onPayConfirm});

  @override
  State<FinePaymentDialog> createState() => _FinePaymentDialogState();
}

class _FinePaymentDialogState extends State<FinePaymentDialog> {
  String? _proofFile;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Verifikasi Pembayaran Denda', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 12),
            Text(widget.fine.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            const SizedBox(height: 2),
            Text(
              'Tagihan: Rp ${widget.fine.amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text('Metode Pembayaran Transfer:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
            const Text('• Bank Mandiri: 123-000-456-7890 (a.n Pustaka Digital)', style: TextStyle(fontSize: 9.5, color: Colors.black87)),
            const Text('• E-Wallet GOPAY / OVO: 0812-3456-789', style: TextStyle(fontSize: 9.5, color: Colors.black87)),
            const SizedBox(height: 16),

            // Mock File Uploader
            const Text('Unggah Bukti Transfer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                setState(() {
                  _proofFile = 'transfer_bukti_denda_${widget.fine.id}.png';
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, style: BorderStyle.values[0] /* dashed simulation in custom painter usually, here simple solid border is fine */),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50,
                ),
                child: _proofFile == null
                    ? const Column(
                        children: [
                          Icon(Icons.upload_file_outlined, color: Colors.grey, size: 24),
                          SizedBox(height: 4),
                          Text('Simulasikan Unggah Foto', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 9.5)),
                          Text('Klik untuk mensimulasikan upload file bukti', style: TextStyle(color: Colors.grey, fontSize: 8)),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          const SizedBox(width: 6),
                          Text(_proofFile!, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.green)),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _proofFile = null;
                              });
                            },
                            child: const Icon(Icons.delete, color: Colors.red, size: 16),
                          )
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _proofFile == null
                        ? null
                        : () {
                            widget.onPayConfirm(_proofFile!);
                            Navigator.pop(context);
                          },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4ED8), foregroundColor: Colors.white),
                    child: const Text('Konfirmasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}

// EDIT PROFILE DIALOG
class EditProfileDialog extends StatefulWidget {
  final String initialName;
  final Function(String) onSave;

  const EditProfileDialog({super.key, required this.initialName, required this.onSave});

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ubah Profil Anggota', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nama Lengkap',
              border: OutlineInputBorder(),
            ),
          )
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.trim().isNotEmpty) {
              widget.onSave(_nameController.text.trim());
              Navigator.pop(context);
            }
          },
          child: const Text('Simpan'),
        )
      ],
    );
  }
}
