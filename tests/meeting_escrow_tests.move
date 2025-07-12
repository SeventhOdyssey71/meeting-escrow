#[test_only]
module meeting_escrow::meeting_tests {
    use sui::test_scenario::{Self};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use meeting_escrow::meeting::{Self, MeetingRequest};

    const USER1: address = @0xCAFE;
    const USER2: address = @0xBEEF;
    const MEETING_AMOUNT: u64 = 1000;

    #[test]
    fun test_create_meeting() {
        let mut scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // User1 creates a meeting request
        test_scenario::next_tx(scenario, USER1);
        {
            meeting::create_meeting(USER2, MEETING_AMOUNT, test_scenario::ctx(scenario));
        };
        
        // Verify meeting was created
        test_scenario::next_tx(scenario, USER1);
        {
            let meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            assert!(meeting::is_meeting_active(&meeting), 0);
            assert!(!meeting::is_meeting_confirmed(&meeting), 1);
            test_scenario::return_shared(meeting);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_deposit_user2_success() {
        let mut scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // User1 creates a meeting request
        test_scenario::next_tx(scenario, USER1);
        {
            meeting::create_meeting(USER2, MEETING_AMOUNT, test_scenario::ctx(scenario));
        };
        
        // User2 deposits funds
        test_scenario::next_tx(scenario, USER2);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let payment = coin::mint_for_testing<SUI>(MEETING_AMOUNT, test_scenario::ctx(scenario));
            meeting::deposit_user2(&mut meeting, payment, test_scenario::ctx(scenario));
            test_scenario::return_shared(meeting);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = 0, location = meeting_escrow::meeting)]
    fun test_deposit_user2_wrong_amount() {
        let mut scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // User1 creates a meeting request
        test_scenario::next_tx(scenario, USER1);
        {
            meeting::create_meeting(USER2, MEETING_AMOUNT, test_scenario::ctx(scenario));
        };
        
        // User2 tries to deposit wrong amount
        test_scenario::next_tx(scenario, USER2);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let payment = coin::mint_for_testing<SUI>(MEETING_AMOUNT + 100, test_scenario::ctx(scenario));
            meeting::deposit_user2(&mut meeting, payment, test_scenario::ctx(scenario));
            test_scenario::return_shared(meeting);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = 2, location = meeting_escrow::meeting)]
    fun test_deposit_user2_unauthorized() {
        let mut scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // User1 creates a meeting request
        test_scenario::next_tx(scenario, USER1);
        {
            meeting::create_meeting(USER2, MEETING_AMOUNT, test_scenario::ctx(scenario));
        };
        
        // User1 tries to deposit instead of User2
        test_scenario::next_tx(scenario, USER1);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let payment = coin::mint_for_testing<SUI>(MEETING_AMOUNT, test_scenario::ctx(scenario));
            meeting::deposit_user2(&mut meeting, payment, test_scenario::ctx(scenario));
            test_scenario::return_shared(meeting);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_confirm_meeting_success() {
        let mut scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // User1 creates a meeting request
        test_scenario::next_tx(scenario, USER1);
        {
            meeting::create_meeting(USER2, MEETING_AMOUNT, test_scenario::ctx(scenario));
        };
        
        // User2 deposits funds
        test_scenario::next_tx(scenario, USER2);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let payment = coin::mint_for_testing<SUI>(MEETING_AMOUNT, test_scenario::ctx(scenario));
            meeting::deposit_user2(&mut meeting, payment, test_scenario::ctx(scenario));
            test_scenario::return_shared(meeting);
        };
        
        // User1 confirms meeting
        test_scenario::next_tx(scenario, USER1);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let payment = coin::mint_for_testing<SUI>(MEETING_AMOUNT, test_scenario::ctx(scenario));
            meeting::confirm_meeting(&mut meeting, payment, test_scenario::ctx(scenario));
            assert!(meeting::is_meeting_confirmed(&meeting), 0);
            test_scenario::return_shared(meeting);
        };
        
        // Verify User1 received the payment
        test_scenario::next_tx(scenario, USER1);
        {
            let payment = test_scenario::take_from_sender<Coin<SUI>>(scenario);
            assert!(coin::value(&payment) == MEETING_AMOUNT, 1);
            test_scenario::return_to_sender(scenario, payment);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = 2, location = meeting_escrow::meeting)]
    fun test_confirm_meeting_unauthorized() {
        let mut scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // User1 creates a meeting request
        test_scenario::next_tx(scenario, USER1);
        {
            meeting::create_meeting(USER2, MEETING_AMOUNT, test_scenario::ctx(scenario));
        };
        
        // User2 tries to confirm meeting instead of User1
        test_scenario::next_tx(scenario, USER2);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let payment = coin::mint_for_testing<SUI>(MEETING_AMOUNT, test_scenario::ctx(scenario));
            meeting::confirm_meeting(&mut meeting, payment, test_scenario::ctx(scenario));
            test_scenario::return_shared(meeting);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = 3, location = meeting_escrow::meeting)]
    fun test_double_confirm_fails() {
        let mut scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // User1 creates a meeting request
        test_scenario::next_tx(scenario, USER1);
        {
            meeting::create_meeting(USER2, MEETING_AMOUNT, test_scenario::ctx(scenario));
        };
        
        // User2 deposits funds
        test_scenario::next_tx(scenario, USER2);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let payment = coin::mint_for_testing<SUI>(MEETING_AMOUNT, test_scenario::ctx(scenario));
            meeting::deposit_user2(&mut meeting, payment, test_scenario::ctx(scenario));
            test_scenario::return_shared(meeting);
        };
        
        // User1 confirms meeting
        test_scenario::next_tx(scenario, USER1);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let payment = coin::mint_for_testing<SUI>(MEETING_AMOUNT, test_scenario::ctx(scenario));
            meeting::confirm_meeting(&mut meeting, payment, test_scenario::ctx(scenario));
            test_scenario::return_shared(meeting);
        };
        
        // User1 tries to confirm again
        test_scenario::next_tx(scenario, USER1);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let payment = coin::mint_for_testing<SUI>(MEETING_AMOUNT, test_scenario::ctx(scenario));
            meeting::confirm_meeting(&mut meeting, payment, test_scenario::ctx(scenario));
            test_scenario::return_shared(meeting);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_cancel_meeting_with_deposit() {
        let mut scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // User1 creates a meeting request
        test_scenario::next_tx(scenario, USER1);
        {
            meeting::create_meeting(USER2, MEETING_AMOUNT, test_scenario::ctx(scenario));
        };
        
        // User2 deposits funds
        test_scenario::next_tx(scenario, USER2);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let payment = coin::mint_for_testing<SUI>(MEETING_AMOUNT, test_scenario::ctx(scenario));
            meeting::deposit_user2(&mut meeting, payment, test_scenario::ctx(scenario));
            test_scenario::return_shared(meeting);
        };
        
        // User1 cancels meeting
        test_scenario::next_tx(scenario, USER1);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            meeting::cancel_meeting(&mut meeting, test_scenario::ctx(scenario));
            assert!(!meeting::is_meeting_active(&meeting), 0);
            test_scenario::return_shared(meeting);
        };
        
        // Verify User2 got refund
        test_scenario::next_tx(scenario, USER2);
        {
            let refund = test_scenario::take_from_sender<Coin<SUI>>(scenario);
            assert!(coin::value(&refund) == MEETING_AMOUNT, 1);
            test_scenario::return_to_sender(scenario, refund);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_cancel_meeting_no_deposit() {
        let mut scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // User1 creates a meeting request
        test_scenario::next_tx(scenario, USER1);
        {
            meeting::create_meeting(USER2, MEETING_AMOUNT, test_scenario::ctx(scenario));
        };
        
        // User1 cancels meeting before any deposit
        test_scenario::next_tx(scenario, USER1);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            meeting::cancel_meeting(&mut meeting, test_scenario::ctx(scenario));
            assert!(!meeting::is_meeting_active(&meeting), 0);
            test_scenario::return_shared(meeting);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = 2, location = meeting_escrow::meeting)]
    fun test_cancel_meeting_unauthorized() {
        let mut scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // User1 creates a meeting request
        test_scenario::next_tx(scenario, USER1);
        {
            meeting::create_meeting(USER2, MEETING_AMOUNT, test_scenario::ctx(scenario));
        };
        
        // User2 tries to cancel meeting
        test_scenario::next_tx(scenario, USER2);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            meeting::cancel_meeting(&mut meeting, test_scenario::ctx(scenario));
            test_scenario::return_shared(meeting);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = 1, location = meeting_escrow::meeting)]
    fun test_deposit_to_inactive_meeting() {
        let mut scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // User1 creates a meeting request
        test_scenario::next_tx(scenario, USER1);
        {
            meeting::create_meeting(USER2, MEETING_AMOUNT, test_scenario::ctx(scenario));
        };
        
        // User1 cancels meeting
        test_scenario::next_tx(scenario, USER1);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            meeting::cancel_meeting(&mut meeting, test_scenario::ctx(scenario));
            test_scenario::return_shared(meeting);
        };
        
        // User2 tries to deposit to cancelled meeting
        test_scenario::next_tx(scenario, USER2);
        {
            let mut meeting = test_scenario::take_shared<MeetingRequest>(scenario);
            let payment = coin::mint_for_testing<SUI>(MEETING_AMOUNT, test_scenario::ctx(scenario));
            meeting::deposit_user2(&mut meeting, payment, test_scenario::ctx(scenario));
            test_scenario::return_shared(meeting);
        };
        
        test_scenario::end(scenario_val);
    }
}