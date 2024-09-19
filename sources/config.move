module bucket_point_phase1::config {
    
    use std::ascii::{String};
    use sui::vec_map::{Self, VecMap};
    use flask::float::{Self, Float};
    use liquidlink_locker::asset_locker::{AssetLocker};

    const ONE_HOUR: u64 = 3600_000;

    public struct BucketPointPhase1 has drop {}

    public struct BucketPointConfig has key {
        id: UID,
        weights: VecMap<ID, Float>,
        actions: VecMap<ID, String>,
    }

    public struct BucketPointCap has key { id: UID }

    fun init(ctx: &mut TxContext) {
        let config = BucketPointConfig {
            id: object::new(ctx),
            weights: vec_map::empty(),
            actions: vec_map::empty(),
        };
        transfer::share_object(config);
        let cap = BucketPointCap {
            id: object::new(ctx)
        };
        transfer::transfer(cap, ctx.sender());
    }

    public fun get_locker_params<T: store, P: drop>(
        config: &BucketPointConfig,
        locker: &AssetLocker<T, P>,
    ): (Float, String) {
        let locker_id = &object::id(locker);
        (
            *config.weights.get(locker_id),
            *config.actions.get(locker_id),
        )
    }

    public fun duration(): u64 { ONE_HOUR }

    public(package) fun witness(): BucketPointPhase1 {
        BucketPointPhase1 {}
    }

    public(package) fun insert(
        config: &mut BucketPointConfig,
        id: ID,
        weight_percent: u64,
        action_name: String,
    ) {
        config.weights.insert(id, float::from_percent_u64(weight_percent));
        config.actions.insert(id, action_name);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}