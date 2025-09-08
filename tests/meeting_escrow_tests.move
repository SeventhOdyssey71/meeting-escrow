#[test_only]
module meeting_escrow::meeting_tests {
    use sui::test_scenario::{Self};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use meeting_escrow::meeting::{Self, MeetingRequest, AdminCap};

    const USER1: address = @0xCAFE;
    const USER2: address = @0xBEEF;
    const ADMIN: address = @0xADDE;
    const MEETING_AMOUNT: u64 = 1_000_000_000; // 1 SUI
    const FEE_AMOUNT: u64 = 100_000_000; // 0.1 SUI

    #[test]
    fun test_init() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        // Initialize the module
        test_scenario::next_tx(scenario, ADMIN);
        {
            meeting::test_init(test_scenario::ctx(scenario));
        };
        
        // Verify AdminCap was created
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            test_scenario::return_to_sender(scenario, admin_cap);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_create_meeting() {
        let mut scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // Create clock
        test_scenario::next_tx(scenario, USER1);
        {
            let clock = clock::create_for_testing(test_scenario::ctx(scenario));
            clock::share_for_testing(clock);
        };
        
        // User1 creates a meeting request
        test_scenario::next_tx(scenario, USER1);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            meeting::create_meeting(USER2, MEETING_AMOUNT, &clock, test_scenario::ctx(scenario));
            test_scenario::return_shared(clock);
        };
        
        // Verify meeting was created
        test_scenario::next_tx(scenario, USER1);
        {
            let meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            assert!(meeting::is_meeting_active(&meeting), 0);
            assert!(!meeting::is_meeting_confirmed(&meeting), 1);
            assert!(!meeting::is_meeting_completed(&meeting), 2);
            assert!(meeting::get_user1_deposit(&meeting) == 0, 3);
            assert!(meeting::get_user2_deposit(&meeting) == 0, 4);
            test_scenario::return_shared(meeting);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_deposit_funds_both_users() {
        let mut scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // Create clock
        test_scenario::next_tx(scenario, USER1);
        {
            let clock = clock::create_for_testing(test_scenario::ctx(scenario));
            clock::share_for_testing(clock);
        };
        
        // User1 creates a meeting request
        test_scenario::next_tx(scenario, USER1);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            meeting::create_meeting(USER2, MEETING_AMOUNT, &clock, test_scenario::ctx(scenario));
            test_scenario::return_shared(clock);
        };
        
        // User1 deposits funds
        test_scenario::next_tx(scenario, USER1);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let payment = coin::mint_for_testing<SUI>(MEETING_AMOUNT, test_scenario::ctx(scenario));
            meeting::deposit_funds(&mut meeting, payment, &clock, test_scenario::ctx(scenario));
            assert!(meeting::get_user1_deposit(&meeting) == MEETING_AMOUNT, 0);
            test_scenario::return_shared(meeting);
            test_scenario::return_shared(clock);
        };
        
        // User2 deposits funds
        test_scenario::next_tx(scenario, USER2);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let payment = coin::mint_for_testing<SUI>(MEETING_AMOUNT, test_scenario::ctx(scenario));
            meeting::deposit_funds(&mut meeting, payment, &clock, test_scenario::ctx(scenario));
            assert!(meeting::get_user2_deposit(&meeting) == MEETING_AMOUNT, 0);
            test_scenario::return_shared(meeting);
            test_scenario::return_shared(clock);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = 0, location = meeting_escrow::meeting)]
    fun test_deposit_wrong_amount() {
        let mut scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // Create clock
        test_scenario::next_tx(scenario, USER1);
        {
            let clock = clock::create_for_testing(test_scenario::ctx(scenario));
            clock::share_for_testing(clock);
        };
        
        // User1 creates a meeting request
        test_scenario::next_tx(scenario, USER1);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            meeting::create_meeting(USER2, MEETING_AMOUNT, &clock, test_scenario::ctx(scenario));
            test_scenario::return_shared(clock);
        };
        
        // User2 tries to deposit wrong amount
        test_scenario::next_tx(scenario, USER2);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let payment = coin::mint_for_testing<SUI>(MEETING_AMOUNT + 100, test_scenario::ctx(scenario));
            meeting::deposit_funds(&mut meeting, payment, &clock, test_scenario::ctx(scenario));
            test_scenario::return_shared(meeting);
            test_scenario::return_shared(clock);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_confirm_attendance_both_users() {
        let mut scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // Create clock
        test_scenario::next_tx(scenario, USER1);
        {
            let clock = clock::create_for_testing(test_scenario::ctx(scenario));
            clock::share_for_testing(clock);
        };
        
        // User1 creates a meeting request
        test_scenario::next_tx(scenario, USER1);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            meeting::create_meeting(USER2, MEETING_AMOUNT, &clock, test_scenario::ctx(scenario));
            test_scenario::return_shared(clock);
        };
        
        // Both users deposit funds
        test_scenario::next_tx(scenario, USER1);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let payment = coin::mint_for_testing<SUI>(MEETING_AMOUNT, test_scenario::ctx(scenario));
            meeting::deposit_funds(&mut meeting, payment, &clock, test_scenario::ctx(scenario));
            test_scenario::return_shared(meeting);
            test_scenario::return_shared(clock);
        };
        
        test_scenario::next_tx(scenario, USER2);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let payment = coin::mint_for_testing<SUI>(MEETING_AMOUNT, test_scenario::ctx(scenario));
            meeting::deposit_funds(&mut meeting, payment, &clock, test_scenario::ctx(scenario));
            test_scenario::return_shared(meeting);
            test_scenario::return_shared(clock);
        };
        
        // User1 confirms attendance
        test_scenario::next_tx(scenario, USER1);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            meeting::confirm_attendance(&mut meeting, &clock, test_scenario::ctx(scenario));
            assert!(meeting::is_user1_confirmed(&meeting), 0);
            assert!(!meeting::is_user2_confirmed(&meeting), 1);
            test_scenario::return_shared(meeting);
            test_scenario::return_shared(clock);
        };
        
        // User2 confirms attendance
        test_scenario::next_tx(scenario, USER2);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            meeting::confirm_attendance(&mut meeting, &clock, test_scenario::ctx(scenario));
            assert!(meeting::is_user1_confirmed(&meeting), 0);
            assert!(meeting::is_user2_confirmed(&meeting), 1);
            assert!(meeting::is_meeting_confirmed(&meeting), 2);
            test_scenario::return_shared(meeting);
            test_scenario::return_shared(clock);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = 5, location = meeting_escrow::meeting)]
    fun test_confirm_attendance_without_deposit() {
        let mut scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // Create clock
        test_scenario::next_tx(scenario, USER1);
        {
            let clock = clock::create_for_testing(test_scenario::ctx(scenario));
            clock::share_for_testing(clock);
        };
        
        // User1 creates a meeting request
        test_scenario::next_tx(scenario, USER1);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            meeting::create_meeting(USER2, MEETING_AMOUNT, &clock, test_scenario::ctx(scenario));
            test_scenario::return_shared(clock);
        };
        
        // User1 tries to confirm without depositing
        test_scenario::next_tx(scenario, USER1);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            meeting::confirm_attendance(&mut meeting, &clock, test_scenario::ctx(scenario));
            test_scenario::return_shared(meeting);
            test_scenario::return_shared(clock);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_complete_meeting_success() {
        let mut scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // Create clock
        test_scenario::next_tx(scenario, USER1);
        {
            let clock = clock::create_for_testing(test_scenario::ctx(scenario));
            clock::share_for_testing(clock);
        };
        
        // User1 creates a meeting request
        test_scenario::next_tx(scenario, USER1);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            meeting::create_meeting(USER2, MEETING_AMOUNT, &clock, test_scenario::ctx(scenario));
            test_scenario::return_shared(clock);
        };
        
        // Both users deposit first
        test_scenario::next_tx(scenario, USER1);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let payment = coin::mint_for_testing<SUI>(MEETING_AMOUNT, test_scenario::ctx(scenario));
            meeting::deposit_funds(&mut meeting, payment, &clock, test_scenario::ctx(scenario));
            test_scenario::return_shared(meeting);
            test_scenario::return_shared(clock);
        };
        
        test_scenario::next_tx(scenario, USER2);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let payment = coin::mint_for_testing<SUI>(MEETING_AMOUNT, test_scenario::ctx(scenario));
            meeting::deposit_funds(&mut meeting, payment, &clock, test_scenario::ctx(scenario));
            test_scenario::return_shared(meeting);
            test_scenario::return_shared(clock);
        };
        
        // Now both users confirm
        test_scenario::next_tx(scenario, USER1);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            meeting::confirm_attendance(&mut meeting, &clock, test_scenario::ctx(scenario));
            test_scenario::return_shared(meeting);
            test_scenario::return_shared(clock);
        };
        
        test_scenario::next_tx(scenario, USER2);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            meeting::confirm_attendance(&mut meeting, &clock, test_scenario::ctx(scenario));
            test_scenario::return_shared(meeting);
            test_scenario::return_shared(clock);
        };
        
        // Complete the meeting
        test_scenario::next_tx(scenario, USER1);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let fee = coin::mint_for_testing<SUI>(FEE_AMOUNT, test_scenario::ctx(scenario));
            meeting::complete_meeting(&mut meeting, fee, test_scenario::ctx(scenario));
            assert!(meeting::is_meeting_completed(&meeting), 0);
            assert!(!meeting::is_meeting_active(&meeting), 1);
            test_scenario::return_shared(meeting);
        };
        
        // Both users should receive equal amounts
        test_scenario::next_tx(scenario, USER1);
        {
            let payment = test_scenario::take_from_sender<Coin<SUI>>(scenario);
            assert!(coin::value(&payment) == MEETING_AMOUNT, 0);
            test_scenario::return_to_sender(scenario, payment);
        };
        
        test_scenario::next_tx(scenario, USER2);
        {
            let payment = test_scenario::take_from_sender<Coin<SUI>>(scenario);
            assert!(coin::value(&payment) == MEETING_AMOUNT, 0);
            test_scenario::return_to_sender(scenario, payment);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = 6, location = meeting_escrow::meeting)]
    fun test_complete_meeting_without_both_confirmations() {
        let mut scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // Create clock
        test_scenario::next_tx(scenario, USER1);
        {
            let clock = clock::create_for_testing(test_scenario::ctx(scenario));
            clock::share_for_testing(clock);
        };
        
        // User1 creates a meeting request
        test_scenario::next_tx(scenario, USER1);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            meeting::create_meeting(USER2, MEETING_AMOUNT, &clock, test_scenario::ctx(scenario));
            test_scenario::return_shared(clock);
        };
        
        // Both users deposit first
        test_scenario::next_tx(scenario, USER1);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let payment = coin::mint_for_testing<SUI>(MEETING_AMOUNT, test_scenario::ctx(scenario));
            meeting::deposit_funds(&mut meeting, payment, &clock, test_scenario::ctx(scenario));
            test_scenario::return_shared(meeting);
            test_scenario::return_shared(clock);
        };
        
        test_scenario::next_tx(scenario, USER2);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let payment = coin::mint_for_testing<SUI>(MEETING_AMOUNT, test_scenario::ctx(scenario));
            meeting::deposit_funds(&mut meeting, payment, &clock, test_scenario::ctx(scenario));
            test_scenario::return_shared(meeting);
            test_scenario::return_shared(clock);
        };
        
        // Only User1 confirms
        test_scenario::next_tx(scenario, USER1);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            meeting::confirm_attendance(&mut meeting, &clock, test_scenario::ctx(scenario));
            test_scenario::return_shared(meeting);
            test_scenario::return_shared(clock);
        };
        
        // Try to complete without both confirmations
        test_scenario::next_tx(scenario, USER1);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let fee = coin::mint_for_testing<SUI>(FEE_AMOUNT, test_scenario::ctx(scenario));
            meeting::complete_meeting(&mut meeting, fee, test_scenario::ctx(scenario));
            test_scenario::return_shared(meeting);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_cancel_meeting_by_user() {
        let mut scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // Create clock
        test_scenario::next_tx(scenario, USER1);
        {
            let clock = clock::create_for_testing(test_scenario::ctx(scenario));
            clock::share_for_testing(clock);
        };
        
        // User1 creates a meeting request
        test_scenario::next_tx(scenario, USER1);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            meeting::create_meeting(USER2, MEETING_AMOUNT, &clock, test_scenario::ctx(scenario));
            test_scenario::return_shared(clock);
        };
        
        // Both users deposit
        test_scenario::next_tx(scenario, USER1);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let payment = coin::mint_for_testing<SUI>(MEETING_AMOUNT, test_scenario::ctx(scenario));
            meeting::deposit_funds(&mut meeting, payment, &clock, test_scenario::ctx(scenario));
            test_scenario::return_shared(meeting);
            test_scenario::return_shared(clock);
        };
        
        test_scenario::next_tx(scenario, USER2);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let payment = coin::mint_for_testing<SUI>(MEETING_AMOUNT, test_scenario::ctx(scenario));
            meeting::deposit_funds(&mut meeting, payment, &clock, test_scenario::ctx(scenario));
            test_scenario::return_shared(meeting);
            test_scenario::return_shared(clock);
        };
        
        // User1 cancels meeting
        test_scenario::next_tx(scenario, USER1);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            meeting::cancel_meeting(&mut meeting, &clock, test_scenario::ctx(scenario));
            assert!(!meeting::is_meeting_active(&meeting), 0);
            test_scenario::return_shared(meeting);
            test_scenario::return_shared(clock);
        };
        
        // Verify both users got refunds
        test_scenario::next_tx(scenario, USER1);
        {
            let refund = test_scenario::take_from_sender<Coin<SUI>>(scenario);
            assert!(coin::value(&refund) == MEETING_AMOUNT, 0);
            test_scenario::return_to_sender(scenario, refund);
        };
        
        test_scenario::next_tx(scenario, USER2);
        {
            let refund = test_scenario::take_from_sender<Coin<SUI>>(scenario);
            assert!(coin::value(&refund) == MEETING_AMOUNT, 0);
            test_scenario::return_to_sender(scenario, refund);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_cancel_expired_meeting() {
        let mut scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // Create clock
        test_scenario::next_tx(scenario, USER1);
        {
            let clock = clock::create_for_testing(test_scenario::ctx(scenario));
            clock::share_for_testing(clock);
        };
        
        // User1 creates a meeting request
        test_scenario::next_tx(scenario, USER1);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            meeting::create_meeting(USER2, MEETING_AMOUNT, &clock, test_scenario::ctx(scenario));
            test_scenario::return_shared(clock);
        };
        
        // Both users deposit
        test_scenario::next_tx(scenario, USER1);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let payment = coin::mint_for_testing<SUI>(MEETING_AMOUNT, test_scenario::ctx(scenario));
            meeting::deposit_funds(&mut meeting, payment, &clock, test_scenario::ctx(scenario));
            test_scenario::return_shared(meeting);
            test_scenario::return_shared(clock);
        };
        
        test_scenario::next_tx(scenario, USER2);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let payment = coin::mint_for_testing<SUI>(MEETING_AMOUNT, test_scenario::ctx(scenario));
            meeting::deposit_funds(&mut meeting, payment, &clock, test_scenario::ctx(scenario));
            test_scenario::return_shared(meeting);
            test_scenario::return_shared(clock);
        };
        
        // Fast forward time past expiration (4 days)
        test_scenario::next_tx(scenario, USER1);
        {
            let mut clock = test_scenario::take_shared<Clock>(scenario);
            clock::increment_for_testing(&mut clock, 4 * 24 * 60 * 60 * 1000);
            test_scenario::return_shared(clock);
        };
        
        // Anyone can cancel expired meeting
        test_scenario::next_tx(scenario, @0xDEAD); // Random third party
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            meeting::cancel_meeting(&mut meeting, &clock, test_scenario::ctx(scenario));
            assert!(!meeting::is_meeting_active(&meeting), 0);
            test_scenario::return_shared(meeting);
            test_scenario::return_shared(clock);
        };
        
        // Verify both users got refunds
        test_scenario::next_tx(scenario, USER1);
        {
            let refund = test_scenario::take_from_sender<Coin<SUI>>(scenario);
            assert!(coin::value(&refund) == MEETING_AMOUNT, 0);
            test_scenario::return_to_sender(scenario, refund);
        };
        
        test_scenario::next_tx(scenario, USER2);
        {
            let refund = test_scenario::take_from_sender<Coin<SUI>>(scenario);
            assert!(coin::value(&refund) == MEETING_AMOUNT, 0);
            test_scenario::return_to_sender(scenario, refund);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = 4, location = meeting_escrow::meeting)]
    fun test_deposit_to_expired_meeting() {
        let mut scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // Create clock
        test_scenario::next_tx(scenario, USER1);
        {
            let clock = clock::create_for_testing(test_scenario::ctx(scenario));
            clock::share_for_testing(clock);
        };
        
        // User1 creates a meeting request
        test_scenario::next_tx(scenario, USER1);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            meeting::create_meeting(USER2, MEETING_AMOUNT, &clock, test_scenario::ctx(scenario));
            test_scenario::return_shared(clock);
        };
        
        // Fast forward time past expiration
        test_scenario::next_tx(scenario, USER1);
        {
            let mut clock = test_scenario::take_shared<Clock>(scenario);
            clock::increment_for_testing(&mut clock, 4 * 24 * 60 * 60 * 1000);
            test_scenario::return_shared(clock);
        };
        
        // Try to deposit to expired meeting
        test_scenario::next_tx(scenario, USER2);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let payment = coin::mint_for_testing<SUI>(MEETING_AMOUNT, test_scenario::ctx(scenario));
            meeting::deposit_funds(&mut meeting, payment, &clock, test_scenario::ctx(scenario));
            test_scenario::return_shared(meeting);
            test_scenario::return_shared(clock);
        };
        
        test_scenario::end(scenario_val);
    }
}