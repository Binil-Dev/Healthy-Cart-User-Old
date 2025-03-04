import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:healthy_cart_user/core/failures/main_failure.dart';
import 'package:healthy_cart_user/core/general/firebase_collection.dart';
import 'package:healthy_cart_user/features/authentication/domain/facade/i_auth_facade.dart';
import 'package:healthy_cart_user/features/profile/domain/models/user_model.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: IAuthFacade)
class IAuthImpl implements IAuthFacade {
  IAuthImpl(this._firebaseAuth, this._firestore);
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  String? verificationId; // phone verification Id
  int? forceResendingToken;
  late StreamSubscription _streamSubscription;

  @override
  Stream<Either<MainFailure, bool>> verifyPhoneNumber(
      String phoneNumber) async* {
    final StreamController<Either<MainFailure, bool>> controller =
        StreamController<Either<MainFailure, bool>>();

    _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: forceResendingToken,
      verificationCompleted: (PhoneAuthCredential credential) {},
      verificationFailed: (FirebaseAuthException e) {
        if (e.code == 'invalid-phone-number') {
          controller.add(left(const MainFailure.invalidPhoneNumber(
              errMsg: 'Phone number is not valid')));
        } else {
          controller.add(left(MainFailure.invalidPhoneNumber(errMsg: e.code)));
        }
      },
      codeSent: (String verificationId, int? forceResendingToken) {
        //verification id is stored in the state
        this.verificationId = verificationId;
        this.forceResendingToken = forceResendingToken;
        controller.add(right(true));
      },
      codeAutoRetrievalTimeout: (verificationId) {},
    );

    yield* controller.stream;
  }

  @override
  Future<Either<MainFailure, String>> verifySmsCode({
    required String smsCode,
  }) async {
    try {
      final PhoneAuthCredential phoneAuthCredential =
          PhoneAuthProvider.credential(
              verificationId: verificationId ?? "", smsCode: smsCode);

      UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(phoneAuthCredential);

      await saveUser(
        phoneNo: userCredential.user!.phoneNumber!,
        uid: userCredential.user!.uid,
      );

      return right(userCredential.user!.uid);
    } on FirebaseAuthException catch (e) {
      return left(MainFailure.invalidPhoneNumber(errMsg: e.code));
    }
  }

  Future<void> saveUser({
    required String uid,
    required String phoneNo,
  }) async {
    final user = await _firestore
        .collection(FirebaseCollections.userCollection)
        .doc(uid)
        .get();
    if (user.data() != null) {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      final fcmToken = await messaging.getToken();
      await _firestore
          .collection(FirebaseCollections.userCollection)
          .doc(uid)
          .update({'fcmToken': fcmToken});
    } else {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      final fcmToken = await messaging.getToken();
      await _firestore
          .collection(FirebaseCollections.userCollection)
          .doc(uid)
          .set(
            UserModel()
                .copyWith(
                  phoneNo: phoneNo,
                  fcmToken: fcmToken,
                  id: uid,
                  isActive: true,
                )
                .toMap(),
          );
    }
  }

  @override
  Stream<Either<MainFailure, UserModel>> userStreamFetchData(
      String userId) async* {
    final StreamController<Either<MainFailure, UserModel>>
        hospitalStreamController =
        StreamController<Either<MainFailure, UserModel>>();
    try {
      _streamSubscription = _firestore
          .collection(FirebaseCollections.userCollection)
          .doc(userId)
          .snapshots()
          .listen((doc) {
        if (doc.exists) {
          hospitalStreamController.add(
              right(UserModel.fromMap(doc.data() as Map<String, dynamic>)));
        }
      });
    } on FirebaseException catch (e) {
      hospitalStreamController
          .add(left(MainFailure.firebaseException(errMsg: e.code)));
    } catch (e) {
      hospitalStreamController
          .add(left(MainFailure.generalException(errMsg: e.toString())));
    }
    yield* hospitalStreamController.stream;
  }

  @override
  Future<void> cancelStream() async {
    await _streamSubscription.cancel();
  }

  @override
  Future<Either<MainFailure, String>> userLogOut() async {
    try {
      cancelStream();
      await _firebaseAuth.signOut();
      return right('Sucessfully Logged Out');
    } catch (e) {
      return left(const MainFailure.generalException(
          errMsg: "Couldn't able to log out"));
    }
  }
}
