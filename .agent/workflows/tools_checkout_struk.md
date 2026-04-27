---
description: Implementasi Tools Page CineGlobal dengan Checkout Tiket, Struk, Konversi Waktu, dan Konversi Mata Uang
---

# Workflow: Tools Page — Checkout + Struk + Konversi

## Konsep
Alur: **Pilih Tiket → Checkout → Struk Tiket → Tools (Konversi Waktu & Mata Uang)**

Setelah user checkout tiket bioskop, struk akan menampilkan:
- **Konversi Waktu**: jam tayang dalam berbagai timezone (WIB/WITA/WIT/London/Tokyo)
- **Konversi Mata Uang**: harga tiket dalam berbagai mata uang (USD/EUR/JPY/SGD/GBP)

---

## Langkah Implementasi

### Step 1 — Buat Model Data Tiket
Buat class `TicketOrder` di `lib/models/ticket_order.dart`:
```dart
class TicketOrder {
  final String movieTitle;
  final String cinemaName;
  final String showDate;      // contoh: "21 Feb 2026"
  final TimeOfDay showTime;   // jam tayang lokal (WIB)
  final String seatNumber;
  final int quantity;
  final double pricePerTicket; // dalam IDR
}
```

### Step 2 — Buat Checkout Page (`lib/checkout_page.dart`)
- Tampilkan daftar film/tiket yang bisa dipilih (data dummy/statis)
- User pilih film, jam tayang, jumlah tiket, nomor kursi
- Tombol **"Checkout"** → navigasi ke struk

Fields checkout:
- Dropdown pilih film (data dummy 5-10 film populer)
- Dropdown jam tayang (list waktu)
- Input jumlah tiket (stepper)
- Pilih kelas (Regular/Velvet/Gold)
- Tombol "Bayar & Checkout"

### Step 3 — Buat Struk Page (`lib/struk_page.dart`)
Tampilan struk digital bergaya tiket bioskop:
```
┌─────────────────────────────┐
│   🎬  CINEGLOBAL            │
│   STRUK PEMBELIAN TIKET     │
├─────────────────────────────┤
│ Film   : [Nama Film]        │
│ Bioskop: [Nama Bioskop]     │
│ Tanggal: [dd MMM yyyy]      │
│ Kursi  : [A1, A2]           │
├ - - - - - - - - - - - - - -┤
│ 2x Tiket Regular   Rp 70.000│
│ Total          Rp 140.000   │
├─────────────────────────────┤
│  🕐 JADWAL TAYANG:          │
│  WIB (UTC+7)   : 19:00      │
│  WITA (UTC+8)  : 20:00      │
│  WIT (UTC+9)   : 21:00      │
│  London (UTC+0): 12:00      │
│  Tokyo (UTC+9) : 21:00      │
├─────────────────────────────┤
│  💱 HARGA TIKET:            │
│  IDR  : Rp 140.000          │
│  USD  : $ 8.75              │
│  EUR  : € 8.02              │
│  SGD  : S$ 11.73            │
│  JPY  : ¥ 1.290             │
└─────────────────────────────┘
```

### Step 4 — Konversi Waktu (di Struk)
Logic konversi timezone dari WIB (UTC+7):
```dart
// Dari showTime WIB, hitung ke timezone lain
DateTime baseWIB = DateTime(now.year, now.month, now.day, hour, minute);
DateTime utc = baseWIB.subtract(const Duration(hours: 7));
DateTime wita = utc.add(const Duration(hours: 8));
DateTime wit = utc.add(const Duration(hours: 9));
DateTime london = utc; // UTC+0
DateTime tokyo = utc.add(const Duration(hours: 9));
```

### Step 5 — Konversi Mata Uang (di Struk)
Gunakan exchange rate statis (atau API gratis):
```dart
const Map<String, double> rateFromIDR = {
  'USD': 0.0000624,  // 1 IDR = 0.0000624 USD
  'EUR': 0.0000571,
  'GBP': 0.0000488,
  'SGD': 0.0000836,
  'JPY': 0.0092,
  'MYR': 0.000294,
};
// Opsional: fetch dari API https://api.exchangerate-api.com/v4/latest/IDR
```

### Step 6 — Update Tools Page
Ubah `tools_page.dart` menjadi entry point untuk:
1. **Tab/Card "Beli Tiket"** → navigasi ke CheckoutPage
2. **Tab "Riwayat Struk"** → list struk yang pernah dibuat
3. **Card "Konversi Waktu"** → standalone konverter timezone
4. **Card "Konversi Mata Uang"** → standalone konverter currency

### Step 7 — Integrasi Navigasi
Update `main.dart` / bottom nav agar Tools Page sudah bisa diakses.
Struk page bisa dibuka dari:
- Setelah checkout (push route)
- Dari riwayat struk (list)

---

## File yang Dimodifikasi/Dibuat
| File | Aksi |
|------|------|
| `lib/tools_page.dart` | MODIFY — redesign sebagai hub |
| `lib/checkout_page.dart` | NEW — halaman checkout tiket |
| `lib/struk_page.dart` | NEW — halaman struk + konversi |
| `lib/models/ticket_order.dart` | NEW — model data |

---

## Urutan Pengerjaan yang Disarankan
1. Buat model `TicketOrder`
2. Buat `checkout_page.dart` (form checkout)
3. Buat `struk_page.dart` (struk + konversi waktu & mata uang)
4. Redesign `tools_page.dart` sebagai hub
5. Sambungkan navigasi antar halaman
6. Test alur end-to-end
