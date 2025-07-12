module meeting_escrow::meeting {
    use sui::coin::{Coin};
    use sui::balance::{Balance};
    use sui::sui::SUI;

    // Errors
    const EWrongAmount: u64 = 0;
    const EMeetingNotActive: u64 = 1;
    const EUnauthorized: u64 = 2;
    const EMeetingAlreadyConfirmed: u64 = 3;

    // Meeting Request object
    public struct MeetingRequest has key {
        id: UID,
        user1: address,      // Meeting creator
        user2: address,      // Meeting joiner
        amount: u64,         // Required amount from each user
        user2_balance: Balance<SUI>,
        is_active: bool,
        is_confirmed: bool
    }

    // Create new meeting request
    public entry fun create_meeting(
        user2: address,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let meeting = MeetingRequest {
            id: sui::object::new(ctx),
            user1: sui::tx_context::sender(ctx),
            user2,
            amount,
            user2_balance: sui::balance::zero(),
            is_active: true,
            is_confirmed: false
        };
        sui::transfer::share_object(meeting);
    }

    // User2 deposits funds
    public entry fun deposit_user2(
        meeting: &mut MeetingRequest,
        payment: Coin<SUI>,
        ctx: &TxContext
    ) {
        // Verify conditions
        assert!(meeting.is_active, EMeetingNotActive);
        assert!(sui::tx_context::sender(ctx) == meeting.user2, EUnauthorized);
        assert!(sui::coin::value(&payment) == meeting.amount, EWrongAmount);
        assert!(!meeting.is_confirmed, EMeetingAlreadyConfirmed);
        
        // Process deposit
        let payment_balance = sui::coin::into_balance(payment);
        sui::balance::join(&mut meeting.user2_balance, payment_balance);
    }

    // User1 confirms and pays for meeting
    public entry fun confirm_meeting(
        meeting: &mut MeetingRequest,
        payment: Coin<SUI>,
        ctx: &TxContext
    ) {
        // Verify conditions
        assert!(meeting.is_active, EMeetingNotActive);
        assert!(sui::tx_context::sender(ctx) == meeting.user1, EUnauthorized);
        assert!(sui::coin::value(&payment) == meeting.amount, EWrongAmount);
        assert!(!meeting.is_confirmed, EMeetingAlreadyConfirmed);
        
        // Process User1's payment and confirm meeting
        sui::transfer::public_transfer(payment, meeting.user1);
        meeting.is_confirmed = true;
    }

    // Cancel meeting (only User1 can cancel)
    public entry fun cancel_meeting(
        meeting: &mut MeetingRequest,
        ctx: &mut TxContext
    ) {
        // Verify conditions
        assert!(meeting.is_active, EMeetingNotActive);
        assert!(sui::tx_context::sender(ctx) == meeting.user1, EUnauthorized);
        assert!(!meeting.is_confirmed, EMeetingAlreadyConfirmed);
        
        // Return User2's deposit if any
        let balance_value = sui::balance::value(&meeting.user2_balance);
        if (balance_value > 0) {
            let split_balance = sui::balance::split(&mut meeting.user2_balance, balance_value);
            let return_payment = sui::coin::from_balance(split_balance, ctx);
            sui::transfer::public_transfer(return_payment, meeting.user2);
        };
        
        meeting.is_active = false;
    }

    // Check meeting status
    public fun is_meeting_confirmed(meeting: &MeetingRequest): bool {
        meeting.is_confirmed
    }

    // Check if meeting is active
    public fun is_meeting_active(meeting: &MeetingRequest): bool {
        meeting.is_active
    }
}
