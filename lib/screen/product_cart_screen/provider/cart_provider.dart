import 'dart:developer';
import 'package:e_shop/utility/utility_extention.dart';

import '../../../models/coupon.dart';
import '../../login_screen/provider/user_provider.dart';
import '../../../services/http_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cart/flutter_cart.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../core/data/data_provider.dart';
import '../../../models/api_response.dart';
import '../../../utility/constants.dart';
import '../../../utility/snack_bar_helper.dart';

class CartProvider extends ChangeNotifier {
  HttpService service = HttpService();
  final box = GetStorage();
  Razorpay razorpay = Razorpay();
  final UserProvider _userProvider;
  var flutterCart = FlutterCart();
  List<CartModel> myCartItems = [];

  final GlobalKey<FormState> buyNowFormKey = GlobalKey<FormState>();
  TextEditingController phoneController = TextEditingController();
  TextEditingController streetController = TextEditingController();
  TextEditingController cityController = TextEditingController();
  TextEditingController stateController = TextEditingController();
  TextEditingController postalCodeController = TextEditingController();
  TextEditingController countryController = TextEditingController();
  TextEditingController couponController = TextEditingController();
  bool isExpanded = false;

  Coupon? couponApplied;
  double couponCodeDiscount = 0;
  String selectedPaymentOption = 'prepaid';

  CartProvider(this._userProvider);

  void updateCart(CartModel cartItem, int quantity) {
    quantity = cartItem.quantity + quantity;
    flutterCart.updateQuantity(cartItem.productId, cartItem.variants, quantity);
    notifyListeners();
  }

  double getCartSubTotal() {
    return flutterCart.subtotal;
  }

  getCartItems() {
    myCartItems = flutterCart.cartItemsList;
    notifyListeners();
  }

  getGrandTotal() {
    return getCartSubTotal() - couponCodeDiscount;
  }

  clearCartItems() {
    flutterCart.clearCart();
    notifyListeners();
  }

  checkCoupon() async {
    try {
      if (couponController.text.isEmpty) {
        SnackBarHelper.showErrorSnackBar('Enter a couponcode');
        return;
      }
      List<String> productIds =
          myCartItems.map((cartItem) => cartItem.productId).toList();
      Map<String, dynamic> couponData = {
        "couponCode": couponController.text,
        "purchaseAmount": getCartSubTotal(),
        "productIds": productIds,
      };
      final response = await service.addItem(
          endpointUrl: 'couponCodes/check-coupon', itemData: couponData);
      if (response.isOk) {
        final ApiResponse<Coupon> apiResponse = ApiResponse<Coupon>.fromJson(
            response.body,
            (json) => Coupon.fromJson(json as Map<String, dynamic>));
        if (apiResponse.success == true) {
          Coupon? coupon = apiResponse.data;
          if (coupon != null) {
            couponApplied = coupon;
            couponCodeDiscount = getCouponDiscountAmount(coupon);
          }
          SnackBarHelper.showSuccessSnackBar(apiResponse.message);
        } else {
          SnackBarHelper.showErrorSnackBar(
              'Failed to validate coupon: ${apiResponse.message}');
        }
      } else {
        SnackBarHelper.showErrorSnackBar(
            'Error: ${response.body?['message'] ?? response.statusText}');
      }
    } catch (e) {
      log(e.toString());
      SnackBarHelper.showErrorSnackBar('An error occured: $e');
    }
  }

  double getCouponDiscountAmount(Coupon coupon) {
    double discountAmount = 0;
    String discountType = coupon.discountType ?? 'fixed';
    if (discountType == 'fixed') {
      discountAmount = coupon.discountAmount ?? 0;
      return discountAmount;
    } else {
      double discountPercentage = coupon.discountAmount ?? 0;
      double amountAfterDiscountPercentage =
          getCartSubTotal() * (discountPercentage / 100);
      return amountAfterDiscountPercentage;
    }
  }

  addOrder(BuildContext context) async {
    try {
      Map<String, dynamic> order = {
        "userID": _userProvider.getLoginUsr()?.sId ?? '', // d
        "orderStatus": "pending",
        "items": cartItemToOrderItem(myCartItems),
        "totalPrice": getCartSubTotal(), //d
        "shippingAddress": {
          "phone": phoneController.text, // d
          "street": streetController.text, // d
          "city": cityController.text, // d
          "state": stateController.text, // d
          "postalCode": postalCodeController.text, // d
          "country": countryController.text, // d
        },
        "paymentMethod": selectedPaymentOption, //d
        "couponCode": couponApplied?.sId, // d
        "orderTotal": {
          "subtotal": getCartSubTotal(), //d
          "discount": couponCodeDiscount, //d
          "total": getGrandTotal(), //d
        },
        "trackingUrl": ""
      };

      final response =
          await service.addItem(endpointUrl: 'orders', itemData: order);
      if (response.isOk) {
        ApiResponse apiResponse = ApiResponse.fromJson(response.body, null);
        if (apiResponse.success == true) {
          SnackBarHelper.showSuccessSnackBar(apiResponse.message);
          clearCouponDiscount();
          clearCartItems();
          // ignore: use_build_context_synchronously
          Navigator.pop(context);
        } else {
          SnackBarHelper.showErrorSnackBar(apiResponse.message);
        }
      } else {
        SnackBarHelper.showErrorSnackBar(
            'Error: ${response.body?['message'] ?? response.statusText}');
      }
    } catch (e) {
      SnackBarHelper.showErrorSnackBar('An error occured: $e');
      rethrow;
    }
  }

  List<Map<String, dynamic>> cartItemToOrderItem(List<CartModel> cartItems) {
    return cartItems.map((cartItem) {
      print('Variants: ${cartItem.variants}');
      return {
        "productID": cartItem.productId,
        "productName": cartItem.productName,
        "quantity": cartItem.quantity,
        "price": cartItem.variants.safeElementAt(0)?.price ?? 0,
        "variant": cartItem.variants.safeElementAt(0)?.color ?? ""
      };
    }).toList();
  }

  submitOrder(BuildContext context) async {
    if (selectedPaymentOption == 'cod') {
      addOrder(context);
    } else {
      await razorpayPayment(operation: () {
        addOrder(context);
      });
    }
  }

  clearCouponDiscount() {
    couponApplied = null;
    couponCodeDiscount = 0;
    couponController.text = '';
    notifyListeners();
  }

  void retrieveSavedAddress() {
    phoneController.text = box.read(PHONE_KEY) ?? '';
    streetController.text = box.read(STREET_KEY) ?? '';
    cityController.text = box.read(CITY_KEY) ?? '';
    stateController.text = box.read(STATE_KEY) ?? '';
    postalCodeController.text = box.read(POSTAL_CODE_KEY) ?? '';
    countryController.text = box.read(COUNTRY_KEY) ?? '';
  }

  Future<void> stripePayment({required void Function() operation}) async {
    try {
      Map<String, dynamic> paymentData = {
        "email": _userProvider.getLoginUsr()?.name,
        "name": _userProvider.getLoginUsr()?.name,
        "address": {
          "line1": streetController.text,
          "city": cityController.text,
          "state": stateController.text,
          "postal_code": postalCodeController.text,
          "country": "US"
        },
        "amount": getGrandTotal() * 100,
        "currency": "usd",
        "description": "Your transaction description here"
      };
      Response response = await service.addItem(
          endpointUrl: 'payment/stripe', itemData: paymentData);
      final data = await response.body;
      final paymentIntent = data['paymentIntent'];
      final ephemeralKey = data['ephemeralKey'];
      final customer = data['customer'];
      final publishableKey = data['publishableKey'];

      Stripe.publishableKey = publishableKey;
      BillingDetails billingDetails = BillingDetails(
        email: _userProvider.getLoginUsr()?.name,
        phone: '91234123908',
        name: _userProvider.getLoginUsr()?.name,
        address: Address(
            country: 'US',
            city: cityController.text,
            line1: streetController.text,
            line2: stateController.text,
            postalCode: postalCodeController.text,
            state: stateController.text
            // Other address details
            ),
        // Other billing details
      );
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          customFlow: false,
          merchantDisplayName: 'MOBIZATE',
          paymentIntentClientSecret: paymentIntent,
          customerEphemeralKeySecret: ephemeralKey,
          customerId: customer,
          style: ThemeMode.light,
          billingDetails: billingDetails,
          // googlePay: const PaymentSheetGooglePay(
          //   merchantCountryCode: 'US',
          //   currencyCode: 'usd',
          //   testEnv: true,
          // ),
          // applePay: const PaymentSheetApplePay(merchantCountryCode: 'US')
        ),
      );

      await Stripe.instance.presentPaymentSheet().then((value) {
        log('payment success');
        //? do the success operation
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          const SnackBar(content: Text('Payment Success')),
        );
        operation();
      }).onError((error, stackTrace) {
        if (error is StripeException) {
          ScaffoldMessenger.of(Get.context!).showSnackBar(
            SnackBar(content: Text('${error.error.localizedMessage}')),
          );
        } else {
          ScaffoldMessenger.of(Get.context!).showSnackBar(
            SnackBar(content: Text('Stripe Error: $error')),
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> razorpayPayment({required void Function() operation}) async {
    try {
      Response response =
          await service.addItem(endpointUrl: 'payment/razorpay', itemData: {});
      final data = await response.body;
      String? razorpayKey = data['key'];
      print(_userProvider.getLoginUsr()?.name);
      print(razorpayKey);
      if (razorpayKey != null && razorpayKey != '') {
        var options = {
          'key': razorpayKey,
          'amount': getGrandTotal() * 100,
          'name': "user",
          "currency": 'INR',
          'description': 'Your transaction description',
          'send_sms_hash': true,
          "prefill": {
            "email": _userProvider.getLoginUsr()?.name,
            "contact": ''
          },
          "theme": {'color': '#FFE64A'},
          "image":
              'https://store.rapidflutter.com/digitalAssetUpload/rapidlogo.png',
        };
        razorpay.open(options);
        razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS,
            (PaymentSuccessResponse response) {
          operation();
          return;
        });
        razorpay.on(Razorpay.EVENT_PAYMENT_ERROR,
            (PaymentFailureResponse response) {
    print('Payment error code: ${response.code}');
  print('Payment error message: ${response.message}');
  print('Payment error description: ${response.error}');
          SnackBarHelper.showErrorSnackBar('Error1 ${response.message}');
          return;
        });
      }
    } catch (e) {
      SnackBarHelper.showErrorSnackBar('Error2$e');
      return;
    }
  }

  void updateUI() {
    notifyListeners();
  }
}