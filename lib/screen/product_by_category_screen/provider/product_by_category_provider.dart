import '../../../models/brand.dart';
import '../../../models/category.dart';
import 'package:flutter/cupertino.dart';
import '../../../core/data/data_provider.dart';
import '../../../models/product.dart';
import '../../../models/sub_category.dart';

class ProductByCategoryProvider extends ChangeNotifier {
  final DataProvider _dataProvider;
  Category? mySelectedCategory;
  SubCategory? mySelectedSubCategory;
  List<SubCategory> subCategories = [];
  List<Brand> brands = [];
  List<Brand> selectedBrands = [];
  List<Product> filteredProduct = [];

  ProductByCategoryProvider(this._dataProvider);

  filterInitialProductAndSubCategory(Category selectedCategory) {
    mySelectedSubCategory = SubCategory(name: 'All');
    mySelectedCategory = selectedCategory;
    subCategories = _dataProvider.subCategories
        .where((element) => element.categoryId?.sId == selectedCategory.sId)
        .toList();
    subCategories.insert(0, SubCategory(name: 'All'));
    filteredProduct = _dataProvider.products
        .where(
            (element) => element.proCategoryId?.name == selectedCategory.name)
        .toList();
    notifyListeners();
  }

  filterProductBySubCategory(SubCategory subCategory) {
    mySelectedSubCategory = subCategory;
    if (subCategory.name?.toLowerCase() == 'all') {
      filteredProduct = _dataProvider.products
          .where((element) =>
              element.proCategoryId?.sId == mySelectedCategory?.sId)
          .toList();
      brands = [];
    } else {
      //This will filter product by it's sub category name
      filteredProduct = _dataProvider.products
          .where(
              (element) => element.proSubCategoryId?.name == subCategory.name)
          .toList();
      // filter product by brand name
      brands = _dataProvider.brands
          .where((element) => element.subcategoryId?.sId == subCategory.sId)
          .toList();
    }
    notifyListeners();
  }

  void filterProductByBrand() {
    if (selectedBrands.isEmpty) {
      //if no brands are selected
      filteredProduct = _dataProvider.products
          .where((product) =>
              product.proSubCategoryId?.name == mySelectedSubCategory?.name)
          .toList();
    } else {
      filteredProduct = _dataProvider.products
          .where((product) =>
              product.proSubCategoryId?.name == mySelectedSubCategory?.name &&
              selectedBrands
                  .any((brand) => product.proBrandId?.sId == brand.sId))
          .toList();
    }
  }

  void sortProducts({required bool ascending}) {
    filteredProduct.sort((a, b) {
      if (ascending) {
        return a.price!.compareTo(b.price ?? 0);
      } else {
        return b.price!.compareTo(a.price ?? 0);
      }
    });
    notifyListeners();
  }

  void updateUI() {
    notifyListeners();
  }
}
