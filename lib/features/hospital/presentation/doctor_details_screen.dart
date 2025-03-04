import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:healthy_cart_user/core/custom/app_bars/sliver_custom_appbar.dart';
import 'package:healthy_cart_user/core/custom/button_widget/button_widget.dart';
import 'package:healthy_cart_user/core/custom/loading_indicators/loading_indicater.dart';
import 'package:healthy_cart_user/core/custom/toast/toast.dart';
import 'package:healthy_cart_user/core/services/easy_navigation.dart';
import 'package:healthy_cart_user/features/authentication/application/provider/authenication_provider.dart';
import 'package:healthy_cart_user/features/hospital/application/provider/hospital_provider.dart';
import 'package:healthy_cart_user/features/hospital/domain/models/doctor_model.dart';
import 'package:healthy_cart_user/features/hospital/domain/models/hospital_model.dart';
import 'package:healthy_cart_user/features/hospital/presentation/doctor_booking_screen.dart';
import 'package:healthy_cart_user/features/hospital/presentation/widgets/doctor_card.dart';
import 'package:healthy_cart_user/features/hospital/presentation/widgets/doctor_details_top_card.dart';
import 'package:healthy_cart_user/features/profile/presentation/profile_setup.dart';
import 'package:healthy_cart_user/utils/constants/colors/colors.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';

class DoctorDetailsScreen extends StatefulWidget {
  const DoctorDetailsScreen({
    super.key,
    required this.hospital,
    required this.doctorModel,
  });

  final HospitalModel hospital;
  final DoctorModel doctorModel;

  @override
  State<DoctorDetailsScreen> createState() => _DoctorDetailsScreenState();
}

class _DoctorDetailsScreenState extends State<DoctorDetailsScreen> {
          final scrollController = ScrollController();
  @override
  void initState() {
    final hospitalProvider = context.read<HospitalProvider>();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        
        hospitalProvider
            .getCategoryWiseDoctor(
                hospitalId: widget.hospital.id ?? '',
                categoryId: widget.doctorModel.categoryId ?? '')
            .whenComplete(
          () {
            hospitalProvider.setRelatedSelectedDoctor(
                selectedDoctorId: widget.doctorModel.id ?? '');
          },
        );
      },
    );
        hospitalProvider.doctorinit(
        scrollController: scrollController,
        hospitalId: widget.doctorModel.id ?? '');
 
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<HospitalProvider, AuthenticationProvider>(
        builder: (context, hospitalProvider, authProvider, _) {
      final doctor = hospitalProvider.relatedSelectedDoctor;
      return PopScope(
        onPopInvoked: (didPop) {
          hospitalProvider.clearDoctorData();
          hospitalProvider.getDoctors(hospitalId: widget.hospital.id ?? '');
        },
        child: Scaffold(
          body: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverCustomAppbar(
                onBackTap: () {
                  EasyNavigation.pop(context: context);
                },
                title: doctor?.doctorName ?? 'Doctor',
              ),
              if (hospitalProvider.isLoading == true &&
                  hospitalProvider.doctorsList.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: LoadingIndicater(),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                    child: DoctorDetailsTopCard(
                        doctors: doctor ?? DoctorModel(), isBooking: false)),
              ),
              const SliverGap(8),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: ButtonWidget(
                      buttonHeight: 48,
                      buttonWidth: double.infinity,
                      buttonColor: BColors.mainlightColor,
                      buttonWidget: const Text(
                        'Make An Appoinment',
                        style: TextStyle(
                            color: BColors.white, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () {
                        if (authProvider.userFetchlDataFetched!.userName ==
                            null) {
                          EasyNavigation.push(
                              type: PageTransitionType.rightToLeft,
                              duration: 250,
                              context: context,
                              page: const ProfileSetup());
                          CustomToast.infoToast(text: 'Fill user details');
                        } else {
                          EasyNavigation.push(
                              context: context,
                              page: DoctorBookingScreen(
                                hospital: widget.hospital,
                                doctorModel: doctor ?? DoctorModel(),
                              ),
                              type: PageTransitionType.rightToLeft,
                              duration: 250);
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SliverGap(24),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Divider(),
                      Gap(12),
                      Text(
                        'Related Doctors',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              (hospitalProvider.doctorsList.isEmpty)
                  ? const SliverFillRemaining(
                      child: Center(
                      child: Text('No related doctors are currently available!'),
                    ))
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList.separated(
                        separatorBuilder: (context, index) => const Gap(5),
                        itemCount: hospitalProvider.doctorsList.length,
                        itemBuilder: (context, index) {
                          final doctorRelated = hospitalProvider.doctorsList[index];

                          if (doctor?.id == doctorRelated.id  ) {
                            return const SizedBox.shrink();
                          } else {
                            return FadeIn(
                              child: GestureDetector(
                                  onTap: () {
                                    EasyNavigation.pushReplacement(
                                      context: context,
                                      page: DoctorDetailsScreen(
                                          hospital: widget.hospital,
                                          doctorModel: hospitalProvider
                                              .doctorsList[index]),
                                    );
                                  },
                                  child: DoctorCard(
                                    fromHomePage: false,
                                    doctor: hospitalProvider.doctorsList[index]),
                                  ),
                            );
                          }
                        },
                      ),
                    ),
                  SliverToBoxAdapter(
                  child: (hospitalProvider.isLoading == true &&
                          hospitalProvider.doctorsList.isNotEmpty)
                      ? const Center(child: LoadingIndicater())
                      :null),
            ],
          ),
        ),
      );
    });
  }
}
