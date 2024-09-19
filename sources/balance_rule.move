/// ST_SBUCK: 0xd01d27939064d79e4ae1179cd11cfeeff23943f32b1a842ea1a1e15a0045d77d::st_sbuck::ST_SBUCK
module bucket_point_phase1::balance_rule {
    
    use std::ascii::{String};
    use sui::balance::{Balance};
    use sui::clock::{Clock};
    use liquidlink_locker::{
        asset_locker::{AssetLocker},
        balance_locker,
    };
    use flask::float;
    use bucket_point_phase1::config::{
        Self, BucketPointConfig, BucketPointCap, BucketPointPhase1
    };
    

    const ERR_INSUFFICIENT_TO_WITHDRAW: u64 = 101;
    fun err_insufficient_to_withdraw() { abort ERR_INSUFFICIENT_TO_WITHDRAW }

    public fun create_balance_locker<T>(
        config: &mut BucketPointConfig,
        _cap: &BucketPointCap,
        weight_percent: u64,
        action_name: String,
        ctx: &mut TxContext,
    ) {
        let locker_id = balance_locker::create<T, BucketPointPhase1>(
            &config::witness(), ctx,
        );
        config.insert(locker_id, weight_percent, action_name);
    }

    public fun deposit<T>(
        config: &BucketPointConfig,
        locker: &mut AssetLocker<Balance<T>, BucketPointPhase1>,
        clock: &Clock,
        collateral: Balance<T>,
        ctx: &mut TxContext,
    ) {
        let (weight, action) = config.get_locker_params(locker);
        let point = float::from(collateral.value()).mul(weight).floor() as u256;
        balance_locker::lock<T, BucketPointPhase1>(
            locker,
            &mut config::witness(),
            ctx.sender(),
            collateral,
            action,
            point,   
            config::duration(),
            clock,
            ctx
        );
    }

    public fun withdraw<T>(
        config: &BucketPointConfig,
        locker: &mut AssetLocker<Balance<T>, BucketPointPhase1>,
        clock: &Clock,
        withdrawal_amt: u64,
        ctx: &mut TxContext
    ): Balance<T> {
        let sender = ctx.sender();
        let owner_balance = balance_locker::owner_locked_balance(locker, sender);
        if (withdrawal_amt > owner_balance) err_insufficient_to_withdraw();
        let new_balance = owner_balance - withdrawal_amt;
        let (weight, action) = config.get_locker_params(locker);
        let point = float::from(new_balance).mul(weight).floor() as u256;
        balance_locker::unlock<T, BucketPointPhase1>(
            locker,
            &mut config::witness(),
            sender,
            withdrawal_amt,
            action,
            point,   
            config::duration(),
            clock,
            ctx
        )
    }
}