module meeting_escrow::meeting {
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use sui::event::emit;
    use sui::package;

    // Errors
    const EWrongAmount: u64 = 0;
    const EMeetingNotActive: u64 = 1;
    const EUnauthorized: u64 = 2;
    const EMeetingAlreadyConfirmed: u64 = 3;
    const EMeetingExpired: u64 = 4;
    const EInsufficientDeposit: u64 = 5;
    const EBothPartiesNotConfirmed: u64 = 6;
    const EInsufficientFee: u64 = 7;
    
    // Constants
    const FEE_AMOUNT: u64 = 100_000_000; // 0.1 SUI platform fee
    const FEE_RECIPIENT: address = @0x1; // Platform fee recipient  
    const EXPIRATION_TIME_MS: u64 = 3 * 24 * 60 * 60 * 1000; // 3 days in milliseconds

    // One-Time Witness for package publisher
    public struct MEETING has drop {}
    
    // Admin capability for platform management
    public struct AdminCap has key, store {
        id: UID,
        owner: address
    }

    // Meeting Request object
    public struct MeetingRequest has key {
        id: UID,
        user1: address,               // Meeting creator
        user2: address,               // Meeting joiner
        amount: u64,                  // Required amount from each user
        user1_balance: Balance<SUI>,  // User1's deposit
        user2_balance: Balance<SUI>,  // User2's deposit
        user1_confirmed: bool,         // User1 confirmation
        user2_confirmed: bool,         // User2 confirmation
        is_active: bool,
        is_completed: bool,
        expiration: u64,               // Expiration timestamp
        created_at: u64                // Creation timestamp
    }
    
    // Events
    public struct MeetingCreated has copy, drop {
        id: ID,
        user1: address,
        user2: address,
        amount: u64,
        expiration: u64
    }
    
    public struct MeetingDeposited has copy, drop {
        id: ID,
        user: address,
        amount: u64
    }
    
    public struct MeetingConfirmed has copy, drop {
        id: ID,
        user: address
    }
    
    public struct MeetingCompleted has copy, drop {
        id: ID,
        total_amount: u64
    }
    
    public struct MeetingCancelled has copy, drop {
        id: ID,
        reason: vector<u8>
    }
    
    // Init function for package publisher
    fun init(otw: MEETING, ctx: &mut TxContext) {
        transfer::public_transfer(package::claim(otw, ctx), tx_context::sender(ctx));
        transfer::public_transfer(
            AdminCap {
                id: object::new(ctx),
                owner: tx_context::sender(ctx),
            },
            tx_context::sender(ctx),
        );
    }

    // Create new meeting request with expiration
    public entry fun create_meeting(
        user2: address,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let current_time = clock::timestamp_ms(clock);
        let expiration = current_time + EXPIRATION_TIME_MS;
        
        let meeting = MeetingRequest {
            id: object::new(ctx),
            user1: sender,
            user2,
            amount,
            user1_balance: balance::zero(),
            user2_balance: balance::zero(),
            user1_confirmed: false,
            user2_confirmed: false,
            is_active: true,
            is_completed: false,
            expiration,
            created_at: current_time,
        };
        
        let meeting_id = object::id(&meeting);
        
        emit(MeetingCreated {
            id: meeting_id,
            user1: sender,
            user2,
            amount,
            expiration,
        });
        
        transfer::share_object(meeting);
    }

    // Deposit funds (both users can deposit)
    public entry fun deposit_funds(
        meeting: &mut MeetingRequest,
        payment: Coin<SUI>,
        clock: &Clock,
        ctx: &TxContext
    ) {
        // Check if meeting hasn't expired
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time <= meeting.expiration, EMeetingExpired);
        assert!(meeting.is_active, EMeetingNotActive);
        assert!(!meeting.is_completed, EMeetingAlreadyConfirmed);
        
        let sender = tx_context::sender(ctx);
        let payment_value = coin::value(&payment);
        assert!(payment_value == meeting.amount, EWrongAmount);
        
        // Determine which user is depositing and update appropriate balance
        if (sender == meeting.user1) {
            let payment_balance = coin::into_balance(payment);
            balance::join(&mut meeting.user1_balance, payment_balance);
        } else if (sender == meeting.user2) {
            let payment_balance = coin::into_balance(payment);
            balance::join(&mut meeting.user2_balance, payment_balance);
        } else {
            abort EUnauthorized
        };
        
        emit(MeetingDeposited {
            id: object::id(meeting),
            user: sender,
            amount: payment_value,
        });
    }

    // Confirm meeting attendance (both users must confirm)
    public entry fun confirm_attendance(
        meeting: &mut MeetingRequest,
        clock: &Clock,
        ctx: &TxContext
    ) {
        // Check if meeting hasn't expired
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time <= meeting.expiration, EMeetingExpired);
        assert!(meeting.is_active, EMeetingNotActive);
        assert!(!meeting.is_completed, EMeetingAlreadyConfirmed);
        
        let sender = tx_context::sender(ctx);
        
        // Check deposits are made
        assert!(balance::value(&meeting.user1_balance) >= meeting.amount, EInsufficientDeposit);
        assert!(balance::value(&meeting.user2_balance) >= meeting.amount, EInsufficientDeposit);
        
        // Mark confirmation for the appropriate user
        if (sender == meeting.user1) {
            meeting.user1_confirmed = true;
        } else if (sender == meeting.user2) {
            meeting.user2_confirmed = true;
        } else {
            abort EUnauthorized
        };
        
        emit(MeetingConfirmed {
            id: object::id(meeting),
            user: sender,
        });
    }
    
    // Complete meeting and distribute funds (requires both confirmations)
    public entry fun complete_meeting(
        meeting: &mut MeetingRequest,
        fee_payment: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        // Verify conditions
        assert!(meeting.is_active, EMeetingNotActive);
        assert!(!meeting.is_completed, EMeetingAlreadyConfirmed);
        assert!(meeting.user1_confirmed && meeting.user2_confirmed, EBothPartiesNotConfirmed);
        assert!(coin::value(&fee_payment) >= FEE_AMOUNT, EInsufficientFee);
        
        // Calculate total pool
        let user1_amount = balance::value(&meeting.user1_balance);
        let user2_amount = balance::value(&meeting.user2_balance);
        let total_amount = user1_amount + user2_amount;
        
        // Split funds equally between both parties
        let each_gets = total_amount / 2;
        
        // Process fee payment
        transfer::public_transfer(fee_payment, FEE_RECIPIENT);
        
        // Distribute funds to user1
        if (each_gets > 0 && user1_amount > 0) {
            let mut user1_split = balance::split(&mut meeting.user1_balance, user1_amount);
            if (user2_amount > 0 && each_gets > user1_amount) {
                let extra_from_user2 = balance::split(&mut meeting.user2_balance, each_gets - user1_amount);
                balance::join(&mut user1_split, extra_from_user2);
            };
            let user1_coin = coin::from_balance(user1_split, ctx);
            transfer::public_transfer(user1_coin, meeting.user1);
        };
        
        // Distribute remaining funds to user2
        let remaining_balance = balance::value(&meeting.user2_balance);
        if (remaining_balance > 0) {
            let user2_split = balance::split(&mut meeting.user2_balance, remaining_balance);
            let user2_coin = coin::from_balance(user2_split, ctx);
            transfer::public_transfer(user2_coin, meeting.user2);
        };
        
        meeting.is_completed = true;
        meeting.is_active = false;
        
        emit(MeetingCompleted {
            id: object::id(meeting),
            total_amount,
        });
    }

    // Cancel meeting (either party can cancel or auto-cancel on expiration)
    public entry fun cancel_meeting(
        meeting: &mut MeetingRequest,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Verify conditions
        assert!(meeting.is_active, EMeetingNotActive);
        assert!(!meeting.is_completed, EMeetingAlreadyConfirmed);
        
        let sender = tx_context::sender(ctx);
        let current_time = clock::timestamp_ms(clock);
        let is_expired = current_time > meeting.expiration;
        
        // Allow cancellation if sender is participant or meeting expired
        assert!(
            sender == meeting.user1 || 
            sender == meeting.user2 || 
            is_expired, 
            EUnauthorized
        );
        
        // Return deposits to respective users
        let user1_balance_value = balance::value(&meeting.user1_balance);
        if (user1_balance_value > 0) {
            let user1_refund = balance::split(&mut meeting.user1_balance, user1_balance_value);
            let user1_coin = coin::from_balance(user1_refund, ctx);
            transfer::public_transfer(user1_coin, meeting.user1);
        };
        
        let user2_balance_value = balance::value(&meeting.user2_balance);
        if (user2_balance_value > 0) {
            let user2_refund = balance::split(&mut meeting.user2_balance, user2_balance_value);
            let user2_coin = coin::from_balance(user2_refund, ctx);
            transfer::public_transfer(user2_coin, meeting.user2);
        };
        
        meeting.is_active = false;
        
        let reason = if (is_expired) {
            b"expired"
        } else {
            b"cancelled_by_user"
        };
        
        emit(MeetingCancelled {
            id: object::id(meeting),
            reason,
        });
    }

    // === View Functions ===
    
    // Check if both parties confirmed
    public fun is_meeting_confirmed(meeting: &MeetingRequest): bool {
        meeting.user1_confirmed && meeting.user2_confirmed
    }

    // Check if meeting is active
    public fun is_meeting_active(meeting: &MeetingRequest): bool {
        meeting.is_active
    }
    
    // Check if meeting is completed
    public fun is_meeting_completed(meeting: &MeetingRequest): bool {
        meeting.is_completed
    }
    
    // Get meeting expiration time
    public fun get_expiration(meeting: &MeetingRequest): u64 {
        meeting.expiration
    }
    
    // Get user1 confirmation status
    public fun is_user1_confirmed(meeting: &MeetingRequest): bool {
        meeting.user1_confirmed
    }
    
    // Get user2 confirmation status  
    public fun is_user2_confirmed(meeting: &MeetingRequest): bool {
        meeting.user2_confirmed
    }
    
    // Get deposited amounts
    public fun get_user1_deposit(meeting: &MeetingRequest): u64 {
        balance::value(&meeting.user1_balance)
    }
    
    public fun get_user2_deposit(meeting: &MeetingRequest): u64 {
        balance::value(&meeting.user2_balance)
    }
    
    // === Test Functions ===
    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(MEETING {}, ctx)
    }
}
