class ProductionCostType {
  final String key;
  final String name;

  const ProductionCostType({required this.key, required this.name});

  static const List<ProductionCostType> defaults = [
    ProductionCostType(key: 'LABOUR', name: 'Labour'),
    ProductionCostType(key: 'ELECTRICITY', name: 'Electricity'),
    ProductionCostType(key: 'UTILITY', name: 'Utility'),
    ProductionCostType(key: 'PACKAGING', name: 'Packaging'),
    ProductionCostType(key: 'FACTORY_OVERHEAD', name: 'Factory Overhead'),
    ProductionCostType(key: 'MACHINE_TOOLS', name: 'Machine & Tools'),
    ProductionCostType(key: 'PRODUCTION_HANDLING', name: 'Production Handling'),
    ProductionCostType(key: 'WASTAGE', name: 'Wastage'),
    ProductionCostType(key: 'QUALITY_CONTROL', name: 'Quality Control'),
    ProductionCostType(key: 'OTHER', name: 'Other'),
  ];
}
