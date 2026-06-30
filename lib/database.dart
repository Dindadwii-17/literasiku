import 'models.dart';

List<Book> getInitialBooks() {
  return [
    Book(
      id: 'book-1',
      title: 'Filosofi Teras',
      author: 'Henry Manampiring',
      category: 'Fiksi',
      cover: 'https://images.unsplash.com/photo-1544947950-fa07a98d237f?auto=format&fit=crop&w=150&q=80',
      available: true,
      year: '2019',
      publisher: 'Kompas',
      pages: '320',
      desc: 'Filosofi Teras adalah buku pengantar Stoisisme yang dikemas khusus untuk masyarakat modern. Menjelaskan cara mengatasi kekhawatiran berlebih, kecemasan sosial, dan emosi negatif secara rasional.',
      reviews: [
        Review(
          user: 'Budi Santoso',
          rating: 5,
          comment: 'Sangat mengubah mindset saya dalam menghadapi kegelisahan sehari-hari. Recommended!',
          date: '2026-05-12',
        ),
        Review(
          user: 'Siti Aminah',
          rating: 4,
          comment: 'Penjelasannya ringan dan mudah dipahami oleh pemula.',
          date: '2026-06-01',
        ),
      ],
    ),
    Book(
      id: 'book-2',
      title: 'Kecerdasan Buatan Terapan',
      author: 'Prof. Dr. Ir. Gunawan',
      category: 'Teknologi',
      cover: 'https://images.unsplash.com/photo-1532012197267-da84d127e765?auto=format&fit=crop&w=150&q=80',
      available: true,
      year: '2022',
      publisher: 'Andi Offset',
      pages: '280',
      desc: 'Buku ini memandu pembaca memahami dasar pembelajaran mesin, kecerdasan buatan, visual komputer, dan NLP lengkap dengan implementasi pemrograman Python sederhana.',
      reviews: [
        Review(
          user: 'Rendi Wijaya',
          rating: 4,
          comment: 'Buku wajib untuk memulai eksplorasi AI secara praktis.',
          date: '2026-03-20',
        ),
      ],
    ),
    Book(
      id: 'book-3',
      title: 'Sejarah Gelap Dunia',
      author: 'Michael Farquhar',
      category: 'Sejarah',
      cover: 'https://images.unsplash.com/photo-1509021436665-8f07dbf5bf1d?auto=format&fit=crop&w=150&q=80',
      available: true,
      year: '2018',
      publisher: 'Pustaka Jaya',
      pages: '412',
      desc: 'Kumpulan cerita menarik tentang berbagai rahasia gelap, konspirasi, intrik kerajaan, dan skandal para tokoh sejarah dunia yang mengubah alur peradaban.',
      reviews: [
        Review(
          user: 'Lina Marlina',
          rating: 5,
          comment: 'Penuh dengan intrik masa lalu yang mencengangkan!',
          date: '2026-01-15',
        ),
      ],
    ),
    Book(
      id: 'book-4',
      title: 'Fisika Kuantum untuk Pemula',
      author: 'Dr. Albert Siregar',
      category: 'Sains',
      cover: 'https://images.unsplash.com/photo-1516979187457-637abb4f9353?auto=format&fit=crop&w=150&q=80',
      available: false,
      year: '2021',
      publisher: 'Erlangga',
      pages: '210',
      desc: 'Mengupas misteri dunia atom, paradoks kucing Schrödinger, superposisi, dan keterikatan kuantum menggunakan bahasa santai tanpa rumus yang rumit.',
      reviews: [
        Review(
          user: 'Dewi Lestari',
          rating: 4,
          comment: 'Bahasanya membumi sekali untuk topik sesulit fisika kuantum.',
          date: '2026-04-10',
        ),
      ],
    ),
    Book(
      id: 'book-5',
      title: 'Bumi dan Alam Semesta',
      author: 'Rina Hartono',
      category: 'Sains',
      cover: 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&w=150&q=80',
      available: true,
      year: '2024',
      publisher: 'Bintang Utama',
      pages: '350',
      desc: 'Eksplorasi geologi bumi dan perjalanannya melintasi ruang angkasa, menelusuri bagaimana planet biru kita terbentuk dan potensi kehidupan lain di galaksi.',
      reviews: [],
    ),
    Book(
      id: 'book-6',
      title: 'Gadis Kretek',
      author: 'Ratih Kumala',
      category: 'Fiksi',
      cover: 'https://images.unsplash.com/photo-1589829085413-56de8ae18c73?auto=format&fit=crop&w=150&q=80',
      available: true,
      year: '2012',
      publisher: 'Gramedia',
      pages: '274',
      desc: 'Mengisahkan perjalanan cinta tragis di industri tembakau tradisional nusantara serta mengungkap keterlibatan sejarah kelam kemerdekaan Indonesia di balik keharuman cengkeh.',
      reviews: [
        Review(
          user: 'Citra Kirana',
          rating: 5,
          comment: 'Sangat puitis, kaya akan budaya dan wangi cengkeh!',
          date: '2026-06-18',
        ),
      ],
    ),
  ];
}

List<EBook> getInitialEBooks() {
  return [
    EBook(
      id: 'eb-1',
      title: 'Seni Berpikir Kreatif',
      author: 'Arif Wijaya',
      cover: 'https://images.unsplash.com/photo-1476275466078-4007374efbbe?auto=format&fit=crop&w=150&q=80',
      readCount: '2.5k',
      pages: '150 Hlm',
      chapters: [
        'BAB 1: Membongkar Blokade Pikiran',
        'BAB 2: Teknik Brainstorming Mandiri (Terkunci)',
        'BAB 3: Inspirasi Kebiasaan Sehari-hari (Terkunci)',
      ],
      contents: [
        'Kreativitas bukanlah anugerah mistis semata. Ia adalah otot mental yang bisa dilatih secara disiplin. Dengan mengubah kebiasaan, merangkul kegagalan sebagai bentuk feedback kreatif, serta membangun jejaring ide-ide gila, Anda bisa membongkar kebuntuan kognitif Anda. Mulailah berpikir dari sudut pandang yang jarang dilirik.',
        'Kreativitas tingkat lanjut membutuhkan teknik eksplorasi pikiran mendalam. Pada halaman kedua ini, kita akan membahas cara menghubungkan dua konsep acak yang terpisah jauh sehingga melahirkan solusi inovatif orisinal.',
        'Selamat! Bab penutup ini menguraikan taktik mengubah kreativitas impulsif menjadi kebiasaan profesional yang produktif demi kesuksesan jangka panjang Anda.',
      ],
      reviews: [
        Review(
          user: 'Adi Nugroho',
          rating: 4,
          comment: 'Inspiratif dan praktis untuk dipraktikkan.',
          date: '2026-05-10',
        ),
      ],
    ),
    EBook(
      id: 'eb-2',
      title: 'Panduan Praktis JavaScript',
      author: 'Developer Kita',
      cover: 'https://images.unsplash.com/photo-1579468118864-1b9ea3c0db4a?auto=format&fit=crop&w=150&q=80',
      readCount: '5.2k',
      pages: '190 Hlm',
      chapters: [
        'BAB 1: Variabel dan Tipe Data modern',
        'BAB 2: Keajaiban Arrow Function (Terkunci)',
        'BAB 3: Asynchronous JS Promises (Terkunci)',
      ],
      contents: [
        'JavaScript menguasai web saat ini. Memahami DOM manipulation, penanganan asynchronous, dan konsep ES6+ sangatlah esensial bagi karir developer web masa depan. Melalui latihan praktis, Anda akan belajar mengendalikan element web seutuhnya, membangun interaksi real-time tanpa pusing.',
        'Arrow function memangkas penulisan kode JavaScript Anda secara dramatis. Melalui halaman eksklusif ini, pelajari perilaku dinamis dari "this" lexical context dalam arrow function.',
        'Asynchronous JS adalah tulang punggung aplikasi interaktif berkecepatan tinggi. Pelajari Promise, Async-Await, dan teknik API polling untuk arsitektur front-end kokoh.',
      ],
      reviews: [
        Review(
          user: 'Irfan Hakim',
          rating: 5,
          comment: 'Penjelasan ES6+ sangat mantap langsung paham!',
          date: '2026-06-25',
        ),
      ],
    ),
    EBook(
      id: 'eb-3',
      title: 'Rahasia Sukses Start-Up',
      author: 'Hadi Wardoyo',
      cover: 'https://images.unsplash.com/photo-1554415707-6e8cfc93fe23?auto=format&fit=crop&w=150&q=80',
      readCount: '1.8k',
      pages: '124 Hlm',
      chapters: [
        'BAB 1: Menemukan Product-Market Fit',
        'BAB 2: Strategi Pitching ke VC (Terkunci)',
        'BAB 3: Membangun Growth Hacking (Terkunci)',
      ],
      contents: [
        'Memulai rintisan usaha digital (start-up) memerlukan keuletan yang luar biasa. Banyak pemula gagal karena tidak berfokus pada kebutuhan pasar riil (product-market fit). Buku ini mendemonstrasikan bagaimana metodologi Lean Start-Up bisa mempercepat validasi ide Anda tanpa membakar anggaran modal di fase awal.',
        'Meyakinkan Venture Capital menuntut kemampuan bercerita dan visualisasi angka pertumbuhan yang matang. Temukan rahasia slide presentasi yang berhasil mendatangkan pendanaan ratusan juta.',
        'Growth Hacking adalah kombinasi kreatif pemrograman, analisis data, pemasaran, dan otomatisasi sosial. Kunci utama pelipatgandaan metrik pengguna aktif start-up.',
      ],
      reviews: [],
    ),
  ];
}

List<Loan> getInitialHistory() {
  return [
    Loan(
      id: 'loan-hist-1',
      bookId: 'book-4', // Fisika Kuantum
      title: 'Sains Modern',
      author: 'Dr. Albert Siregar',
      type: 'Fisik',
      cover: 'https://images.unsplash.com/photo-1516979187457-637abb4f9353?auto=format&fit=crop&w=150&q=80',
      dateBorrowed: '10 Mei 2026',
      dueDate: '17 Mei 2026',
      pickupMethod: 'Loket Pelayanan',
      status: 'Selesai',
    ),
  ];
}

List<Fine> getInitialFines() {
  return [
    Fine(
      id: 'fine-1',
      loanId: 'loan-expired-1',
      title: 'Sejarah Gelap Dunia',
      amount: 15000,
      daysOverdue: 15,
      status: 'Belum Bayar',
    ),
  ];
}
