/*
 * Copyright (c) 2018, Psiphon Inc.
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#import "Strings.h"

#if !(TARGET_IS_EXTENSION)
#import "PsiphonClientCommonLibraryHelpers.h"
#endif


@implementation StringUtils : NSObject

+ (NSString *)stringForPeriodUnit:(SKProductPeriodUnit)unit
                 pluralGivenUnits:(NSUInteger)numUnits
                    andAbbreviate:(BOOL)abbreviate API_AVAILABLE(ios(11.2)) {
    NSMutableString *string = [[NSMutableString alloc] init];

    switch (unit) {
        case SKProductPeriodUnitDay:
            [string appendString: @"Day"];
            break;
        case SKProductPeriodUnitWeek:
            if (abbreviate) {
                [string appendString:@"wk"];
            } else {
                [string appendString: @"Week"];
            }
            break;
        case SKProductPeriodUnitMonth:
            if (abbreviate) {
                [string appendString:@"mo"];
            } else {
                [string appendString: @"Month"];
            }
            break;
        case SKProductPeriodUnitYear:
            if (abbreviate) {
                [string appendString:@"yr"];
            } else {
                [string appendString: @"Year"];
            }
            break;
        default:
            [NSException raise:NSGenericException format:@"Unknown period unit %lu", (unsigned long)unit];
    }

    if (numUnits > 1) {
        [string appendString: @"s"];
    }

    if (abbreviate) {
        [string appendString:@"."];
    }

    return string;
}

+ (NSString *)stringForSubscriptionPeriod:(SKProductSubscriptionPeriod *)subscription
                      dropNumOfUnitsIfOne:(BOOL)dropNumOfUnitsIfOne
                            andAbbreviate:(BOOL)abbreviate API_AVAILABLE(ios(11.2)) {

    NSMutableString *string = [[NSMutableString alloc] init];

    // Since Apple sets 1 week as 7 days, we will explicitly return "1 Week".
    if (subscription.numberOfUnits == 7 &&
        subscription.unit == SKProductPeriodUnitDay) {

        if (!dropNumOfUnitsIfOne) {
            [string appendString:@"1 "];
        }

        [string appendString:[StringUtils stringForPeriodUnit:SKProductPeriodUnitWeek
                                             pluralGivenUnits:1
                                                andAbbreviate:abbreviate]];
        return string;
    }

    if (!dropNumOfUnitsIfOne || subscription.numberOfUnits != 1) {
        [string appendFormat:@"%lu", (unsigned long)subscription.numberOfUnits];
    }

    [string appendString:[StringUtils stringForPeriodUnit:subscription.unit
                                         pluralGivenUnits:subscription.numberOfUnits
                                            andAbbreviate:abbreviate]];

    return string;
}

@end


@implementation Strings

+ (NSString *)permissionRequiredAlertTitle {
    return NSLocalizedStringWithDefaultValue(@"PERMISSION_REQUIRED_ALERT__TITLE", nil, [NSBundle mainBundle], @"Permission required", @"Alert dialog title indicating to the user that Psiphon needs their permission");
}

+ (NSString *)operationFailedAlertTitle {
    return NSLocalizedStringWithDefaultValue(@"ALERT_TITLE_OPERATION_FAILED", nil, [NSBundle mainBundle], @"Operation Failed", @"Alert dialog title.");
}

+ (NSString *)selectServerRegionTitle {
    return  NSLocalizedStringWithDefaultValue(@"SELECT_SERVER_REGION", nil, [NSBundle mainBundle], @"Select server region", @"Title for screen that allows user to select their desired server region.");
}

+ (NSString *)onboardingSelectLanguageButtonTitle {
    return  NSLocalizedStringWithDefaultValue(@"SELECT_LANG_BUTTON_TITLE", nil, [NSBundle mainBundle], @"Select Language", @"Select language button title.");
}

+ (NSString *)onboardingGettingStartedHeaderText {
    return  NSLocalizedStringWithDefaultValue(@"ONBOARDING_GETTING_STARTED_HEADER", nil, [NSBundle mainBundle], @"Getting Started", @"Onboarding header");
}

+ (NSString *)onboardingGettingStartedBodyText {
    return  NSLocalizedStringWithDefaultValue(@"ONBOARDING_GETTING_STARTED_BODY_2", nil, [NSBundle mainBundle], @"In order to connect, Psiphon needs the ability to add VPN configurations.", @"Onboarding screen 'getting started' body. (Do not translate 'Psiphon').");
}

+ (NSString *)vpnInstallGuideText {
    return  NSLocalizedStringWithDefaultValue(@"ONBOARDING_VPN_INSTALL_GUIDE_TEXT", nil, [NSBundle mainBundle], @"You’ll need to allow Psiphon to add VPN configurations in order to connect.", @"Onboarding text for install VPN configuration. (Do not translate 'Psiphon').");
}

+ (NSString *)nextPageButtonTitle {
    return  NSLocalizedStringWithDefaultValue(@"NEXT_PAGE_BUTTON_TITLE", nil, [NSBundle mainBundle], @"Next", @"Button title that takes user to the next page");
}

+ (NSString *)vpnPermissionDeniedAlertMessage {
    return NSLocalizedStringWithDefaultValue(@"VPN_START_PERMISSION_DENIED_MESSAGE", nil, [NSBundle mainBundle], @"Psiphon needs your permission to install a VPN profile in order to connect.\n\nPsiphon is committed to protecting the privacy of our users. You can review our privacy policy by tapping \"Privacy Policy\".", @"('Privacy Policy' should be the same translation as privacy policy button VPN_START_PRIVACY_POLICY_BUTTON), (Do not translate 'VPN profile'), (Do not translate 'Psiphon')");
}

+ (NSString *)privacyPolicyTitle {
    return NSLocalizedStringWithDefaultValue(@"PrivacyTitle", nil, [NSBundle mainBundle], @"Privacy Policy", @"page title for the Privacy Policy page");
}

+ (NSString *)privacyPolicyButtonTitle {
    return NSLocalizedStringWithDefaultValue(@"VPN_START_PRIVACY_POLICY_BUTTON", nil, [NSBundle mainBundle], @"Privacy Policy", @"Button label taking user's to our Privacy Policy page");
}

+ (NSString *)privacyPolicyDeclinedAlertBody {
    return  NSLocalizedStringWithDefaultValue(@"PRIVACY_POLICY_DECLINED_ALERT_BODY", nil, [NSBundle mainBundle], @"You must accept our Privacy Policy before continuing to use Psiphon.", @"Alert message when the user declined privacy policy. They will not be able to use the app until the user accepts the privacy policy (Do not translate 'Psiphon')");
}

+ (NSString *)activeSubscriptionBannerTitle {
    return NSLocalizedStringWithDefaultValue(@"ACTIVE_SUBSCRIPTION_SECTION_TITLE",
    nil,
    [NSBundle mainBundle],
    @"You're subscribed!",
    @"Title of the section in the subscription dialog that shows currently active subscription information.");
}

+ (NSString *)inactiveSubscriptionBannerTitle {
    return NSLocalizedStringWithDefaultValue(@"SUBSCRIPTIONS_PAGE_BANNER_TITLE_2",
    nil,
    [NSBundle mainBundle],
    @"No ads and maximum speed.",
    @"Title of the banner on the subscriptions page advertising that subscriptions enable no ads and maximum speed.");
}

+ (NSString *)inactiveSubscriptionBannerSubtitle {
    return NSLocalizedStringWithDefaultValue(@"SUBSCRIPTIONS_PAGE_BANNER_SUBTITLE", nil, [NSBundle mainBundle], @"No commitment, cancel anytime.", @"Subtitle of the banner on the subscriptions page informing the user that the subscriptions require no commitment, and can be cancelled anytime");
}

+ (NSString *)manageYourSubscriptionButtonTitle {
    return NSLocalizedStringWithDefaultValue(@"SUBSCRIPTIONS_PAGE_MANAGE_SUBSCRIPTION_BUTTON",
    nil,
    [NSBundle mainBundle],
    @"Manage your subscription",
                                             @"Title of the button on the subscriptions page which takes the user of of the app to iTunes where they can view detailed information about their subscription");
}

+ (NSString *)iDontSeeMySubscriptionButtonTitle {
    return NSLocalizedStringWithDefaultValue(@"SUBSCRIPTIONS_PAGE_RESTORE_SUBSCRIPTION_BUTTON",
    nil,
    [NSBundle mainBundle],
    @"I don't see my subscription",
                                             @"Title of the button on the subscriptions page which, when pressed, navigates the user to the page where they can restore their existing subscription");
}

+ (NSString *)subscriptionScreenNoticeText {
    return NSLocalizedStringWithDefaultValue(@"BUY_SUBSCRIPTIONS_FOOTER_TEXT",
    nil,
    [NSBundle mainBundle],
    @"A subscription is auto-renewable which means that once purchased it will be automatically renewed until you cancel it 24 hours prior to the end of the current period.\n\nYour iTunes Account will be charged for renewal within 24-hours prior to the end of the current period with the cost of the subscription.",
    @"Buy subscription dialog footer text");
}

+ (NSString *)subscriptionScreenCancelNoticeText {
    return NSLocalizedStringWithDefaultValue(@"BUY_SUBSCRIPTIONS_FOOTER_CANCEL_INSTRUCTIONS_TEXT",
    nil,
    [NSBundle mainBundle],
    @"You can cancel an active subscription in your iTunes Account Settings.",
    @"Buy subscription dialog footer text explaining where the user can cancel an active subscription");
}

+ (NSString *)productRequestFailedNoticeText {
    return NSLocalizedStringWithDefaultValue(@"NO_PRODUCTS_TEXT_2", nil, [NSBundle mainBundle],
    @"Could not retrieve subscriptions from the App Store. Please try again later.",
    @"Subscriptions view text that is visible when the list of subscriptions is not available");
}

+ (NSString *)selectedRegionUnavailableAlertBody {
    return NSLocalizedStringWithDefaultValue(@"VPN_START_FAIL_REGION_INVALID_MESSAGE_3", nil, [NSBundle mainBundle], @"The region you selected is no longer available. You have automatically been switched to \"Best performance\".\n\n You can also select a new region from the Psiphon app.", @"Alert dialog message informing the user that an error occurred while starting Psiphon because they selected an egress region that is no longer available (Do not translate 'Psiphon'). The user has been automatically switched to 'Best performance', but they can also open the Psiphon app to choose another country. Note: the backslash before each quotation mark should be left as is for formatting.");
}

#if !(TARGET_IS_EXTENSION)
+ (NSString *)privacyPolicyURLString {
    return NSLocalizedStringWithDefaultValue(@"PRIVACY_POLICY_URL", nil, [PsiphonClientCommonLibraryHelpers commonLibraryBundle], @"https://psiphon.ca/en/privacy.html", @"External link to the privacy policy page. Please update this with the correct language specific link (if available) e.g. https://psiphon.ca/fr/privacy.html for french.");
}
#endif

@end
