/// Accounting platform enumeration for journal exports
enum AccountingPlatform {
  xero,
  myob,
}

/// Chart of Accounts Configuration for General Journal exports (Logbook Running Costs)
/// Compliant with Australian General Ledger conventions and ATO BAS GST reporting.
class ChartOfAccountsConfig {
  final String fuelAccount; // Xero: '449', MYOB: '6-1400'
  final String repairsAccount; // Xero: '449', MYOB: '6-1410'
  final String regoAccount; // Xero: '450', MYOB: '6-1420'
  final String insuranceAccount; // Xero: '450', MYOB: '6-1430'
  final String tollsParkingAccount; // Xero: '453', MYOB: '6-1440'
  final String drawingsAccount; // Xero: '880', MYOB: '3-1800'
  final AccountingPlatform platform; // xero | myob

  const ChartOfAccountsConfig({
    required this.fuelAccount,
    required this.repairsAccount,
    required this.regoAccount,
    required this.insuranceAccount,
    required this.tollsParkingAccount,
    required this.drawingsAccount,
    required this.platform,
  });

  /// Standard Xero default chart of accounts for motor vehicle expenses
  const ChartOfAccountsConfig.xeroDefault()
      : fuelAccount = '449',
        repairsAccount = '449',
        regoAccount = '450',
        insuranceAccount = '450',
        tollsParkingAccount = '453',
        drawingsAccount = '880',
        platform = AccountingPlatform.xero;

  /// Standard MYOB AccountRight / MYOB Practice default chart of accounts
  const ChartOfAccountsConfig.myobDefault()
      : fuelAccount = '6-1400',
        repairsAccount = '6-1410',
        regoAccount = '6-1420',
        insuranceAccount = '6-1430',
        tollsParkingAccount = '6-1440',
        drawingsAccount = '3-1800',
        platform = AccountingPlatform.myob;

  Map<String, dynamic> toJson() {
    return {
      'fuelAccount': fuelAccount,
      'repairsAccount': repairsAccount,
      'regoAccount': regoAccount,
      'insuranceAccount': insuranceAccount,
      'tollsParkingAccount': tollsParkingAccount,
      'drawingsAccount': drawingsAccount,
      'platform': platform.name,
    };
  }

  factory ChartOfAccountsConfig.fromJson(Map<String, dynamic> json) {
    final plat = json['platform'] == 'myob'
        ? AccountingPlatform.myob
        : AccountingPlatform.xero;
    return ChartOfAccountsConfig(
      fuelAccount: (json['fuelAccount'] as String?) ??
          (plat == AccountingPlatform.myob ? '6-1400' : '449'),
      repairsAccount: (json['repairsAccount'] as String?) ??
          (plat == AccountingPlatform.myob ? '6-1410' : '449'),
      regoAccount: (json['regoAccount'] as String?) ??
          (plat == AccountingPlatform.myob ? '6-1420' : '450'),
      insuranceAccount: (json['insuranceAccount'] as String?) ??
          (plat == AccountingPlatform.myob ? '6-1430' : '450'),
      tollsParkingAccount: (json['tollsParkingAccount'] as String?) ??
          (plat == AccountingPlatform.myob ? '6-1440' : '453'),
      drawingsAccount: (json['drawingsAccount'] as String?) ??
          (plat == AccountingPlatform.myob ? '3-1800' : '880'),
      platform: plat,
    );
  }
}
