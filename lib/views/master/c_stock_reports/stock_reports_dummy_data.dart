// ─── REPORT 1: STOCK SUMMARY MODEL ───────────────────────────────────────────
class StockSummaryItem {
  final String groupHead;
  final String category;
  final String metalType;
  final String branch;
  final int itemCount;
  final int openingQty;
  final int stockIn;
  final int stockOut;
  final int closingQty;
  final double weight; // in grams
  final double value; // in INR
  final double ownCust;
  final double ownSup;
  final double custWithUs;
  final double supWithUs;

  const StockSummaryItem({
    required this.groupHead,
    required this.category,
    required this.metalType,
    required this.branch,
    required this.itemCount,
    required this.openingQty,
    required this.stockIn,
    required this.stockOut,
    required this.closingQty,
    required this.weight,
    required this.value,
    this.ownCust = 0.0,
    this.ownSup = 0.0,
    this.custWithUs = 0.0,
    this.supWithUs = 0.0,
  });
}

// ─── REPORT 2: ITEM WISE STOCK BALANCE MODEL ─────────────────────────────────
class ItemWiseStockItem {
  final String itemCode;
  final String itemName;
  final String category;
  final String purity;
  final String branch;
  final int quantity;
  final double grossWeight; // in grams
  final double netWeight; // in grams
  final double value; // in INR
  final int availableQuantity;
  final int soldQuantity;
  final int totalQuantity;
  final double soldPercentage;
  final String productStatus;

  const ItemWiseStockItem({
    required this.itemCode,
    required this.itemName,
    required this.category,
    required this.purity,
    required this.branch,
    required this.quantity,
    required this.grossWeight,
    required this.netWeight,
    required this.value,
    this.availableQuantity = 0,
    this.soldQuantity = 0,
    this.totalQuantity = 0,
    this.soldPercentage = 0.0,
    this.productStatus = 'Shop product',
  });
}

// ─── REPORT 3: TAG WISE STOCK REPORT MODEL ────────────────────────────────────
class TagWiseStockItem {
  final String tagNumber;
  final String barcode;
  final String itemName;
  final String category;
  final double grossWeight;
  final double netWeight;
  final String purity;
  final String status; // 'Available', 'Sold', 'Reserved'
  final String counter;

  const TagWiseStockItem({
    required this.tagNumber,
    required this.barcode,
    required this.itemName,
    required this.category,
    required this.grossWeight,
    required this.netWeight,
    required this.purity,
    required this.status,
    required this.counter,
  });
}

// ─── REPORT 4: COUNTER STOCK REPORT MODEL ─────────────────────────────────────
class CounterStockItem {
  final String counterName;
  final String staff;
  final String category;
  final int itemCount;
  final int quantity;
  final double weight; // in grams
  final double value; // in INR

  const CounterStockItem({
    required this.counterName,
    required this.staff,
    required this.category,
    required this.itemCount,
    required this.quantity,
    required this.weight,
    required this.value,
  });
}

// ─── STATIC DUMMY DATA COLLECTION ─────────────────────────────────────────────
class StockReportsDummyData {
  // Financial Years
  static const List<String> financialYears = [
    '2025 - 2026',
    '2024 - 2025',
    '2023 - 2024',
    '2022 - 2023',
  ];

  // Group Heads
  static const List<String> groupHeads = [
    'All Group Heads',
    'Precious Gold',
    'Diamond Collections',
    'Silverware & Articles',
    'Platinum Luxury',
    'Antique Craft',
  ];

  // Categories
  static const List<String> categories = [
    'All Categories',
    'Gold Necklaces',
    'Gold Chains',
    'Bangles & Bracelets',
    'Rings & Bands',
    'Earrings & Studs',
    'Diamond Solitaires',
    'Silver Coin & Bar',
    'Platinum Chains',
    'Antique Temple Jewellery',
  ];

  // Metal Types
  static const List<String> metalTypes = [
    'All Metal Types',
    'Gold 22K (916)',
    'Gold 18K (750)',
    'Diamond',
    'Silver 925',
    'Platinum 950',
  ];

  // Branches
  static const List<String> branches = [
    'All Branches',
    'Main Branch (Coimbatore)',
    'Showroom Counter A',
    'Showroom Counter B',
    'Vault & Reserves',
  ];

  // Purities
  static const List<String> purities = [
    'All Purities',
    '22K (916 BIS)',
    '18K (750 BIS)',
    '24K (999 Fine)',
    '925 Sterling',
    '950 Platinum',
  ];

  // Counters
  static const List<String> counters = [
    'All Counters',
    'Counter 1 - Gold Bangle',
    'Counter 2 - Neckwear Lounge',
    'Counter 3 - Diamond Boutique',
    'Counter 4 - Silver Articles',
    'Counter 5 - Antique Corner',
    'Main Display Safe',
  ];

  // Staff
  static const List<String> staffList = [
    'All Staff',
    'Ramesh Kumar',
    'Ananya Sharma',
    'Karthik Sundaram',
    'Priya Venkat',
    'Siddharth Menon',
  ];

  // Statuses
  static const List<String> statuses = [
    'All Statuses',
    'Available',
    'Sold',
    'Reserved',
  ];

  // 1. Stock Summary Data
  static final List<StockSummaryItem> stockSummaryList = [
    const StockSummaryItem(
      groupHead: 'Precious Gold',
      category: 'Gold Necklaces',
      metalType: 'Gold 22K (916)',
      branch: 'Main Branch (Coimbatore)',
      itemCount: 142,
      openingQty: 130,
      stockIn: 28,
      stockOut: 16,
      closingQty: 142,
      weight: 4850.75,
      value: 36380625.0,
    ),
    const StockSummaryItem(
      groupHead: 'Precious Gold',
      category: 'Gold Chains',
      metalType: 'Gold 22K (916)',
      branch: 'Main Branch (Coimbatore)',
      itemCount: 215,
      openingQty: 200,
      stockIn: 45,
      stockOut: 30,
      closingQty: 215,
      weight: 3225.50,
      value: 24191250.0,
    ),
    const StockSummaryItem(
      groupHead: 'Precious Gold',
      category: 'Bangles & Bracelets',
      metalType: 'Gold 22K (916)',
      branch: 'Showroom Counter A',
      itemCount: 188,
      openingQty: 175,
      stockIn: 34,
      stockOut: 21,
      closingQty: 188,
      weight: 5640.20,
      value: 42301500.0,
    ),
    const StockSummaryItem(
      groupHead: 'Diamond Collections',
      category: 'Diamond Solitaires',
      metalType: 'Diamond',
      branch: 'Main Branch (Coimbatore)',
      itemCount: 76,
      openingQty: 70,
      stockIn: 18,
      stockOut: 12,
      closingQty: 76,
      weight: 980.40,
      value: 58824000.0,
    ),
    const StockSummaryItem(
      groupHead: 'Precious Gold',
      category: 'Rings & Bands',
      metalType: 'Gold 18K (750)',
      branch: 'Showroom Counter B',
      itemCount: 310,
      openingQty: 290,
      stockIn: 62,
      stockOut: 42,
      closingQty: 310,
      weight: 1550.00,
      value: 9687500.0,
    ),
    const StockSummaryItem(
      groupHead: 'Precious Gold',
      category: 'Earrings & Studs',
      metalType: 'Gold 22K (916)',
      branch: 'Showroom Counter A',
      itemCount: 265,
      openingQty: 250,
      stockIn: 50,
      stockOut: 35,
      closingQty: 265,
      weight: 1855.80,
      value: 13918500.0,
    ),
    const StockSummaryItem(
      groupHead: 'Antique Craft',
      category: 'Antique Temple Jewellery',
      metalType: 'Gold 22K (916)',
      branch: 'Vault & Reserves',
      itemCount: 64,
      openingQty: 60,
      stockIn: 12,
      stockOut: 8,
      closingQty: 64,
      weight: 3840.60,
      value: 30724800.0,
    ),
    const StockSummaryItem(
      groupHead: 'Silverware & Articles',
      category: 'Silver Coin & Bar',
      metalType: 'Silver 925',
      branch: 'Showroom Counter B',
      itemCount: 450,
      openingQty: 400,
      stockIn: 120,
      stockOut: 70,
      closingQty: 450,
      weight: 22500.00,
      value: 2025000.0,
    ),
    const StockSummaryItem(
      groupHead: 'Platinum Luxury',
      category: 'Platinum Chains',
      metalType: 'Platinum 950',
      branch: 'Main Branch (Coimbatore)',
      itemCount: 42,
      openingQty: 40,
      stockIn: 10,
      stockOut: 8,
      closingQty: 42,
      weight: 840.30,
      value: 4621650.0,
    ),
  ];

  // 2. Item Wise Stock Balance Data
  static final List<ItemWiseStockItem> itemWiseList = [
    const ItemWiseStockItem(
      itemCode: 'ITM-G22-NK001',
      itemName: 'Royal Peacock Haar 22K',
      category: 'Gold Necklaces',
      purity: '22K (916 BIS)',
      branch: 'Main Branch (Coimbatore)',
      quantity: 14,
      grossWeight: 680.40,
      netWeight: 640.00,
      value: 5120000.0,
      availableQuantity: 14,
      soldQuantity: 16,
      totalQuantity: 30,
      soldPercentage: 53.33,
      productStatus: 'Shop product',
    ),
    const ItemWiseStockItem(
      itemCode: 'ITM-DIA-RNG04',
      itemName: 'Solitaire Platinum Diamond Ring',
      category: 'Diamond Solitaires',
      purity: '950 Platinum',
      branch: 'Main Branch (Coimbatore)',
      quantity: 28,
      grossWeight: 168.00,
      netWeight: 142.50,
      value: 12825000.0,
      availableQuantity: 28,
      soldQuantity: 12,
      totalQuantity: 40,
      soldPercentage: 30.00,
      productStatus: 'Website product',
    ),
    const ItemWiseStockItem(
      itemCode: 'ITM-G22-BNG12',
      itemName: 'Traditional Antique Kada Bangle',
      category: 'Bangles & Bracelets',
      purity: '22K (916 BIS)',
      branch: 'Showroom Counter A',
      quantity: 36,
      grossWeight: 1152.00,
      netWeight: 1100.00,
      value: 8250000.0,
      availableQuantity: 36,
      soldQuantity: 24,
      totalQuantity: 60,
      soldPercentage: 40.00,
      productStatus: 'Yet to add',
    ),
    const ItemWiseStockItem(
      itemCode: 'ITM-G22-CHN88',
      itemName: 'Mugappu Rope Gold Chain 22K',
      category: 'Gold Chains',
      purity: '22K (916 BIS)',
      branch: 'Main Branch (Coimbatore)',
      quantity: 52,
      grossWeight: 832.00,
      netWeight: 832.00,
      value: 6240000.0,
      availableQuantity: 52,
      soldQuantity: 48,
      totalQuantity: 100,
      soldPercentage: 48.00,
      productStatus: 'Shop product',
    ),
    const ItemWiseStockItem(
      itemCode: 'ITM-ANT-TMP09',
      itemName: 'Lakshmi Temple Haran Antique',
      category: 'Antique Temple Jewellery',
      purity: '22K (916 BIS)',
      branch: 'Vault & Reserves',
      quantity: 8,
      grossWeight: 720.50,
      netWeight: 690.00,
      value: 5520000.0,
      availableQuantity: 8,
      soldQuantity: 2,
      totalQuantity: 10,
      soldPercentage: 20.00,
      productStatus: 'Website product',
    ),
    const ItemWiseStockItem(
      itemCode: 'ITM-G18-EAR33',
      itemName: 'Rose Gold Floral Studs',
      category: 'Earrings & Studs',
      purity: '18K (750 BIS)',
      branch: 'Showroom Counter A',
      quantity: 65,
      grossWeight: 390.00,
      netWeight: 375.00,
      value: 2343750.0,
      availableQuantity: 65,
      soldQuantity: 35,
      totalQuantity: 100,
      soldPercentage: 35.00,
      productStatus: 'Yet to add',
    ),
    const ItemWiseStockItem(
      itemCode: 'ITM-SLV-BAR01',
      itemName: 'Pure Silver Bullion Bar 100g',
      category: 'Silver Coin & Bar',
      purity: '999 Fine Silver',
      branch: 'Showroom Counter B',
      quantity: 120,
      grossWeight: 12000.00,
      netWeight: 12000.00,
      value: 1080000.0,
      availableQuantity: 120,
      soldQuantity: 80,
      totalQuantity: 200,
      soldPercentage: 40.00,
      productStatus: 'Shop product',
    ),
    const ItemWiseStockItem(
      itemCode: 'ITM-PLT-CHN02',
      itemName: 'Men Signature Platinum Chain',
      category: 'Platinum Chains',
      purity: '950 Platinum',
      branch: 'Main Branch (Coimbatore)',
      quantity: 18,
      grossWeight: 450.00,
      netWeight: 450.00,
      value: 2475000.0,
      availableQuantity: 18,
      soldQuantity: 22,
      totalQuantity: 40,
      soldPercentage: 55.00,
      productStatus: 'Website product',
    ),
    const ItemWiseStockItem(
      itemCode: 'ITM-G22-RNG55',
      itemName: 'Navaratna Gold Cocktail Ring',
      category: 'Rings & Bands',
      purity: '22K (916 BIS)',
      branch: 'Showroom Counter B',
      quantity: 42,
      grossWeight: 336.00,
      netWeight: 310.00,
      value: 2325000.0,
      availableQuantity: 42,
      soldQuantity: 18,
      totalQuantity: 60,
      soldPercentage: 30.00,
      productStatus: 'Shop product',
    ),
    const ItemWiseStockItem(
      itemCode: 'ITM-DIA-NK099',
      itemName: 'Emerald Diamond Bridal Choker',
      category: 'Diamond Solitaires',
      purity: '18K (750 BIS)',
      branch: 'Main Branch (Coimbatore)',
      quantity: 5,
      grossWeight: 245.00,
      netWeight: 210.00,
      value: 16800000.0,
      availableQuantity: 5,
      soldQuantity: 15,
      totalQuantity: 20,
      soldPercentage: 75.00,
      productStatus: 'Yet to add',
    ),
  ];

  // 3. Tag Wise Stock Report Data
  static final List<TagWiseStockItem> tagWiseList = [
    const TagWiseStockItem(
      tagNumber: 'TAG-2026-001',
      barcode: '890123450001',
      itemName: '22K Gold Antique Choker',
      category: 'Gold Necklaces',
      grossWeight: 48.50,
      netWeight: 46.20,
      purity: '22K (916 BIS)',
      status: 'Available',
      counter: 'Counter 2 - Neckwear Lounge',
    ),
    const TagWiseStockItem(
      tagNumber: 'TAG-2026-002',
      barcode: '890123450002',
      itemName: 'Diamond Cluster Stud Earrings',
      category: 'Earrings & Studs',
      grossWeight: 8.40,
      netWeight: 7.10,
      purity: '18K (750 BIS)',
      status: 'Available',
      counter: 'Counter 3 - Diamond Boutique',
    ),
    const TagWiseStockItem(
      tagNumber: 'TAG-2026-003',
      barcode: '890123450003',
      itemName: 'Heritage Lakshmi Kada Bangle',
      category: 'Bangles & Bracelets',
      grossWeight: 32.00,
      netWeight: 31.50,
      purity: '22K (916 BIS)',
      status: 'Sold',
      counter: 'Counter 1 - Gold Bangle',
    ),
    const TagWiseStockItem(
      tagNumber: 'TAG-2026-004',
      barcode: '890123450004',
      itemName: 'Platinum Couple Ring (His)',
      category: 'Rings & Bands',
      grossWeight: 6.80,
      netWeight: 6.80,
      purity: '950 Platinum',
      status: 'Reserved',
      counter: 'Counter 3 - Diamond Boutique',
    ),
    const TagWiseStockItem(
      tagNumber: 'TAG-2026-005',
      barcode: '890123450005',
      itemName: '925 Silver Dinner Set Plate',
      category: 'Silver Coin & Bar',
      grossWeight: 450.00,
      netWeight: 450.00,
      purity: '925 Sterling',
      status: 'Available',
      counter: 'Counter 4 - Silver Articles',
    ),
    const TagWiseStockItem(
      tagNumber: 'TAG-2026-006',
      barcode: '890123450006',
      itemName: 'Antique Temple Mango Mala',
      category: 'Antique Temple Jewellery',
      grossWeight: 84.60,
      netWeight: 80.00,
      purity: '22K (916 BIS)',
      status: 'Available',
      counter: 'Counter 5 - Antique Corner',
    ),
    const TagWiseStockItem(
      tagNumber: 'TAG-2026-007',
      barcode: '890123450007',
      itemName: 'Rope Gold Chain 22K 24 Inch',
      category: 'Gold Chains',
      grossWeight: 24.50,
      netWeight: 24.50,
      purity: '22K (916 BIS)',
      status: 'Sold',
      counter: 'Counter 1 - Gold Bangle',
    ),
    const TagWiseStockItem(
      tagNumber: 'TAG-2026-008',
      barcode: '890123450008',
      itemName: '1 Carat Solitaire Diamond Pendant',
      category: 'Diamond Solitaires',
      grossWeight: 5.20,
      netWeight: 4.80,
      purity: '18K (750 BIS)',
      status: 'Available',
      counter: 'Counter 3 - Diamond Boutique',
    ),
    const TagWiseStockItem(
      tagNumber: 'TAG-2026-009',
      barcode: '890123450009',
      itemName: 'Classic Gold Jhumka Earrings',
      category: 'Earrings & Studs',
      grossWeight: 18.20,
      netWeight: 17.00,
      purity: '22K (916 BIS)',
      status: 'Reserved',
      counter: 'Counter 2 - Neckwear Lounge',
    ),
    const TagWiseStockItem(
      tagNumber: 'TAG-2026-010',
      barcode: '890123450010',
      itemName: 'Silver Kalash Puja Article',
      category: 'Silver Coin & Bar',
      grossWeight: 210.00,
      netWeight: 210.00,
      purity: '925 Sterling',
      status: 'Available',
      counter: 'Counter 4 - Silver Articles',
    ),
  ];

  // 4. Counter Stock Report Data
  static final List<CounterStockItem> counterStockList = [
    const CounterStockItem(
      counterName: 'Counter 1 - Gold Bangle',
      staff: 'Ramesh Kumar',
      category: 'Bangles & Bracelets',
      itemCount: 188,
      quantity: 188,
      weight: 5640.20,
      value: 42301500.0,
    ),
    const CounterStockItem(
      counterName: 'Counter 2 - Neckwear Lounge',
      staff: 'Ananya Sharma',
      category: 'Gold Necklaces',
      itemCount: 142,
      quantity: 142,
      weight: 4850.75,
      value: 36380625.0,
    ),
    const CounterStockItem(
      counterName: 'Counter 3 - Diamond Boutique',
      staff: 'Karthik Sundaram',
      category: 'Diamond Solitaires',
      itemCount: 76,
      quantity: 76,
      weight: 980.40,
      value: 58824000.0,
    ),
    const CounterStockItem(
      counterName: 'Counter 4 - Silver Articles',
      staff: 'Priya Venkat',
      category: 'Silver Coin & Bar',
      itemCount: 450,
      quantity: 450,
      weight: 22500.00,
      value: 2025000.0,
    ),
    const CounterStockItem(
      counterName: 'Counter 5 - Antique Corner',
      staff: 'Siddharth Menon',
      category: 'Antique Temple Jewellery',
      itemCount: 64,
      quantity: 64,
      weight: 3840.60,
      value: 30724800.0,
    ),
    const CounterStockItem(
      counterName: 'Main Display Safe',
      staff: 'Vault Manager',
      category: 'Gold Chains',
      itemCount: 215,
      quantity: 215,
      weight: 3225.50,
      value: 24191250.0,
    ),
  ];
}

// ─── REPORT 5: SUPPLIER STOCK MODEL ───────────────────────────────────────────
class SupplierStockItem {
  final String supplierCode;
  final String supplierName;
  final String tagPrefix;
  final String groupName;

  // Purchased
  final int purchasedPcs;
  final double purchasedGrossWt;
  final double purchasedNetWt;
  final double purchasedDiamondWt;
  final double purchasedStoneWt;

  // Tagged (Ever added)
  final int taggedPcs;
  final double taggedGrossWt;
  final double taggedNetWt;
  final double taggedDiamondWt;
  final double taggedStoneWt;

  // Active Counter (Not sold)
  final int activePcs;
  final double activeGrossWt;
  final double activeNetWt;
  final double activeDiamondWt;
  final double activeStoneWt;

  double get remainingGrossWt => purchasedGrossWt - taggedGrossWt;
  double get remainingNetWt => purchasedNetWt - taggedNetWt;
  double get remainingDiamondWt => purchasedDiamondWt - taggedDiamondWt;
  double get remainingStoneWt => purchasedStoneWt - taggedStoneWt;

  const SupplierStockItem({
    required this.supplierCode,
    required this.supplierName,
    required this.tagPrefix,
    required this.groupName,
    this.purchasedPcs = 0,
    this.purchasedGrossWt = 0.0,
    this.purchasedNetWt = 0.0,
    this.purchasedDiamondWt = 0.0,
    this.purchasedStoneWt = 0.0,
    this.taggedPcs = 0,
    this.taggedGrossWt = 0.0,
    this.taggedNetWt = 0.0,
    this.taggedDiamondWt = 0.0,
    this.taggedStoneWt = 0.0,
    this.activePcs = 0,
    this.activeGrossWt = 0.0,
    this.activeNetWt = 0.0,
    this.activeDiamondWt = 0.0,
    this.activeStoneWt = 0.0,
  });
}

