#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export BLOOM_DOMAIN_VECTORS="$root/tests/fixtures/macos-domain-policy.json"
source_dir="$root/src-tauri/macos"
test_dir="$source_dir/tests"
temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT

run_check() {
  local name="$1"
  shift
  xcrun swiftc -parse-as-library -module-name "$name" "$@" -lbsm -o "$temporary_dir/$name"
  "$temporary_dir/$name"
}

run_check WebsiteRulesCheck "$source_dir/filter/WebsiteRules.swift" "$test_dir/WebsiteRulesCheck.swift"
run_check MacHostsPolicyCheck "$source_dir/filter/WebsiteRules.swift" "$source_dir/MacHostsPolicy.swift" "$test_dir/MacHostsPolicyCheck.swift"
run_check MacHostsAuthorizationCheck "$source_dir/MacHostsAuthorization.swift" "$test_dir/MacHostsAuthorizationCheck.swift"
run_check MacHostsTransactionCheck "$source_dir/filter/WebsiteRules.swift" "$source_dir/MacHostsPolicy.swift" "$source_dir/MacHostsTransaction.swift" "$test_dir/MacHostsTransactionCheck.swift"
run_check MacHostsLifecycleCheck "$source_dir/MacHostsLifecycle.swift" "$test_dir/MacHostsLifecycleCheck.swift"
run_check MacHostsPolicyStatusCheck "$source_dir/filter/WebsiteRules.swift" "$source_dir/MacHostsPolicy.swift" "$source_dir/MacHostsTransaction.swift" "$test_dir/MacHostsPolicyStatusCheck.swift"
run_check MacHostsManagedSyncCheck "$source_dir/filter/WebsiteRules.swift" "$source_dir/MacHostsPolicy.swift" "$source_dir/MacHostsTransaction.swift" "$test_dir/MacHostsManagedSyncCheck.swift"
run_check MacHostsEarlyCloseCheck "$source_dir/filter/WebsiteRules.swift" "$source_dir/MacHostsPolicy.swift" "$source_dir/MacHostsTransaction.swift" "$test_dir/MacHostsEarlyCloseCheck.swift"
run_check MacHostsPersistentCheck "$source_dir/filter/WebsiteRules.swift" "$source_dir/MacHostsPolicy.swift" "$source_dir/MacHostsTransaction.swift" "$test_dir/MacHostsPersistentCheck.swift"
run_check MacHostsCrashCheck "$source_dir/filter/WebsiteRules.swift" "$source_dir/MacHostsPolicy.swift" "$source_dir/MacHostsTransaction.swift" "$source_dir/MacHostsRecovery.swift" "$test_dir/MacHostsCrashCheck.swift"
run_check MacHostsRecoveryCoordinatorCheck "$source_dir/filter/WebsiteRules.swift" "$source_dir/MacHostsPolicy.swift" "$source_dir/MacHostsTransaction.swift" "$source_dir/MacHostsRecovery.swift" "$source_dir/MacHostsRecoveryCoordinator.swift" "$test_dir/MacHostsRecoveryCoordinatorCheck.swift"
run_check MacHostsRecoveryCheck "$source_dir/filter/WebsiteRules.swift" "$source_dir/MacHostsPolicy.swift" "$source_dir/MacHostsTransaction.swift" "$source_dir/MacHostsRecovery.swift" "$test_dir/MacHostsRecoveryCheck.swift"
run_check MacHostsEnrollmentCheck "$source_dir/filter/WebsiteRules.swift" "$source_dir/filter/MacFlowSource.swift" "$source_dir/MacPolicyBroker.swift" "$source_dir/MacHostsPolicy.swift" "$source_dir/MacHostsTransaction.swift" "$source_dir/MacHostsHelper.swift" "$source_dir/SupabaseUsageGrant.swift" "$source_dir/MacHostsEnrollment.swift" "$test_dir/MacHostsEnrollmentCheck.swift"
run_check MacHostsVerifiedUsageCheck "$source_dir/filter/WebsiteRules.swift" "$source_dir/filter/MacFlowSource.swift" "$source_dir/MacPolicyBroker.swift" "$source_dir/MacHostsPolicy.swift" "$source_dir/MacHostsTransaction.swift" "$source_dir/SupabaseUsageGrant.swift" "$source_dir/MacHostsVerifiedUsage.swift" "$test_dir/MacHostsVerifiedUsageCheck.swift"
run_check MacHostsHelperCheck "$source_dir/filter/WebsiteRules.swift" "$source_dir/filter/MacFlowSource.swift" "$source_dir/MacPolicyBroker.swift" "$source_dir/MacHostsPolicy.swift" "$source_dir/MacHostsTransaction.swift" "$source_dir/MacHostsHelper.swift" "$test_dir/MacHostsHelperCheck.swift"
run_check FilterCreditClockCheck "$source_dir/filter/FilterCreditClock.swift" "$test_dir/FilterCreditClockCheck.swift"
run_check MacAppRulesCheck "$source_dir/MacAppRules.swift" "$test_dir/MacAppRulesCheck.swift"
run_check MacInstalledAppsCheck "$source_dir/MacAppRules.swift" "$source_dir/MacInstalledApps.swift" "$test_dir/MacInstalledAppsCheck.swift"
run_check MacAppEnforcementCheck "$source_dir/MacAppEnforcement.swift" "$test_dir/MacAppEnforcementCheck.swift"
run_check MacMonitorRulesCheck "$source_dir/MacMonitorRules.swift" "$test_dir/MacMonitorRulesCheck.swift"
run_check MacServiceRegistrationPolicyCheck "$source_dir/MacServiceRegistrationPolicy.swift" "$test_dir/MacServiceRegistrationPolicyCheck.swift"
run_check MacBrowserURLCheck "$source_dir/filter/WebsiteRules.swift" "$source_dir/MacBrowserURL.swift" "$test_dir/MacBrowserURLCheck.swift"
run_check TLSHostnameCheck "$source_dir/filter/WebsiteRules.swift" "$source_dir/filter/TLSHostname.swift" "$test_dir/TLSHostnameCheck.swift"
run_check BloomFilterActivationPolicyCheck "$source_dir/BloomFilterActivationPolicy.swift" "$test_dir/BloomFilterActivationPolicyCheck.swift"
run_check BloomWebsiteCleanupPolicyCheck "$source_dir/BloomWebsiteCleanupPolicy.swift" "$test_dir/BloomWebsiteCleanupPolicyCheck.swift"
run_check MacUsageCheck "$source_dir/BloomAppGroup.swift" "$source_dir/filter/FilterCreditClock.swift" "$source_dir/MacUsageStore.swift" "$test_dir/MacUsageCheck.swift"
run_check MacWebsiteUsageAccessCheck "$source_dir/BloomAppGroup.swift" "$source_dir/filter/WebsiteRules.swift" "$source_dir/filter/FilterCreditClock.swift" "$source_dir/filter/MacFlowSource.swift" "$source_dir/MacPolicyBroker.swift" "$source_dir/MacPolicyBrokerClient.swift" "$source_dir/MacUsageStore.swift" "$source_dir/MacWebsiteUsageAccess.swift" "$test_dir/MacWebsiteUsageAccessCheck.swift"
run_check IosUsageStateCheck "$root/modules/bloom-blocking/ios/BloomUsageState.swift" "$root/tests/IosUsageStateCheck.swift"
run_check MacFlowSourceCheck "$source_dir/filter/WebsiteRules.swift" "$source_dir/filter/MacFlowSource.swift" "$test_dir/MacFlowSourceCheck.swift"
run_check MacPolicyBrokerCheck "$source_dir/filter/WebsiteRules.swift" "$source_dir/filter/MacFlowSource.swift" "$source_dir/MacPolicyBroker.swift" "$source_dir/MacPolicyBrokerIdentity.swift" "$test_dir/MacPolicyBrokerCheck.swift"
run_check BloomPolicyBrokerReadinessCheck "$source_dir/BloomPolicyBrokerReadiness.swift" "$test_dir/BloomPolicyBrokerReadinessCheck.swift"
run_check SupabaseCreditGrantCheck "$source_dir/SupabaseCreditGrant.swift" "$test_dir/SupabaseCreditGrantCheck.swift"
run_check SupabaseUsageGrantCheck "$source_dir/SupabaseUsageGrant.swift" "$source_dir/SupabaseExistingUsageGrant.swift" "$test_dir/SupabaseUsageGrantCheck.swift"

xcrun swiftc -O -parse-as-library -emit-library -module-name BloomFilterHost \
  "$source_dir/BloomAppGroup.swift" "$source_dir/filter/WebsiteRules.swift" "$source_dir/filter/FilterCreditClock.swift" \
  "$source_dir/filter/MacFlowSource.swift" "$source_dir/MacPolicyBroker.swift" "$source_dir/MacPolicyBrokerClient.swift" "$source_dir/MacHostsAuthorization.swift" \
  "$source_dir/MacAppRules.swift" "$source_dir/MacInstalledApps.swift" "$source_dir/MacBrowserURL.swift" "$source_dir/MacBrowserAddress.swift" \
  "$source_dir/MacServiceRegistrationPolicy.swift" \
  "$source_dir/MacUsageStore.swift" "$source_dir/BloomAppController.swift" "$source_dir/BloomFilterController.swift" \
  "$source_dir/BloomPolicyBrokerController.swift" \
  "$source_dir/BloomPolicyBrokerReadiness.swift" \
  "$source_dir/MacSharedPreferences.swift" "$source_dir/SupabaseCreditGrant.swift" "$source_dir/SupabaseUsageGrant.swift" "$source_dir/BloomFilterActivationPolicy.swift" \
  "$source_dir/BloomWebsiteCleanupPolicy.swift" "$source_dir/MacHostsLifecycle.swift" "$source_dir/BloomFilterHost.swift" -lbsm -o "$temporary_dir/libBloomFilterHost.dylib"
xcrun clang "$test_dir/FilterBridgeCheck.c" -o "$temporary_dir/FilterBridgeCheck"
"$temporary_dir/FilterBridgeCheck" "$temporary_dir/libBloomFilterHost.dylib"
