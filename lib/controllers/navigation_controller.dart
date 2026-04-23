import 'package:get/get.dart';

class NavigationController extends GetxController {
  final RxInt currentIndex = 0.obs;
  final RxInt circlesPendingRequestsOpenSignal = 0.obs;

  void navigateToTab(int index) {
    currentIndex.value = index;
  }

  void navigateToProfile() {
    currentIndex.value = 4;
  }

  void navigateToHome() {
    currentIndex.value = 0;
  }

  void navigateToPulse() {
    currentIndex.value = 1;
  }

  void navigateToCircles({bool openPendingRequests = false}) {
    currentIndex.value = 2;
    if (openPendingRequests) {
      circlesPendingRequestsOpenSignal.value++;
    }
  }

  void navigateToMessages() {
    currentIndex.value = 3;
  }
}
