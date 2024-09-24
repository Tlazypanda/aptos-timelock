module deployer_address::timelock {
    use std::string;
    use std::signer;
    use std::vector;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use aptos_framework::aptos_coin::{Self, AptosCoin};

    struct TimeLockFund has key {
        bal: Coin<AptosCoin>,
        unlock_time: u64
    }

    struct RecipientList has key {
        recipients: vector<address>
    }

    const ENOT_ALLOWLISTED: u64 = 1;
    const ELOCKTIME_NOT_ELAPSED: u64 = 2;
   

    public entry fun create_timelock(creator: &signer, amount: u64, lock_dur_secs: u64, recipients: vector<address>){
        let coins = coin::withdraw<AptosCoin>(creator, amount);
        let unlock_time = timestamp::now_seconds() + lock_dur_secs;
        move_to(creator, TimeLockFund{bal: coins, unlock_time: unlock_time});
        move_to(creator, RecipientList{recipients: recipients});
    }

    public entry fun withdraw(caller: &signer, owner_addr: address, amount: u64) acquires TimeLockFund, RecipientList{
        let recipients = borrow_global<RecipientList>(owner_addr).recipients;
        let timelock_fund = borrow_global_mut<TimeLockFund>(owner_addr);
        let caller_addr = signer::address_of(caller);
        assert!(vector::contains(&recipients, &caller_addr), ENOT_ALLOWLISTED);

        assert!(timestamp::now_seconds() >= timelock_fund.unlock_time, ELOCKTIME_NOT_ELAPSED);

        // can only withdraw max half of the fund 
        let bal_amount = coin::value<AptosCoin>(&timelock_fund.bal);


        if(amount>(bal_amount*5)/10){
            amount = (bal_amount*5)/10;
        };


        let withdrawn_coin = coin::extract<AptosCoin>(&mut timelock_fund.bal, amount);
        coin::deposit(caller_addr, withdrawn_coin);
    }

    public fun get_balance(addr: address): u64 acquires TimeLockFund {
        coin::value(&borrow_global<TimeLockFund>(addr).bal)
    }
}