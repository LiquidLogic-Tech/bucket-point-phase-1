module bucket_point_phase1::config {
    
    // Dependencies

    use std::ascii::{String};
    use sui::vec_map::{Self, VecMap};
    use sui::vec_set::{Self, VecSet};
    use flask::float::{Self, Float};
    use liquidlink_locker::asset_locker::{AssetLocker};

    // Constants

    const PACKAGE_VERSION: u64 = 1;
    const ONE_HOUR: u64 = 3600_000;

    // Errors
    
    const EInvalidPackageVersion: u64 = 0;
    fun err_invalid_package_version() { abort EInvalidPackageVersion }

    // Objects

    public struct BucketPointPhase1 has drop {}

    public struct BucketPointConfig has key {
        id: UID,
        weights: VecMap<ID, Float>,
        actions: VecMap<ID, String>,
        valid_versions: VecSet<u64>,
    }

    public struct BucketPointCap has key { id: UID }

    // Constructor

    fun init(ctx: &mut TxContext) {
        let config = BucketPointConfig {
            id: object::new(ctx),
            weights: vec_map::empty(),
            actions: vec_map::empty(),
            valid_versions: vec_set::singleton(package_version()),
        };
        transfer::share_object(config);
        let cap = BucketPointCap {
            id: object::new(ctx)
        };
        transfer::transfer(cap, ctx.sender());
    }

    // Admin Funs

    public fun add_version(
        config: &mut BucketPointConfig,
        _cap: &BucketPointCap,
        package_version: u64,
    ) {
        config.valid_versions.insert(package_version);
    }

    public fun remove_version(
        config: &mut BucketPointConfig,
        _cap: &BucketPointCap,
        package_version: u64,
    ) {
        config.valid_versions.remove(&package_version);
    }

    public fun update_locker_weight(
        config: &mut BucketPointConfig,
        _cap: &BucketPointCap,
        locker_id: ID,
        weight_percent: u64,
    ) {
        config.weights.remove(&locker_id);
        config.weights.insert(
            locker_id, float::from_percent_u64(weight_percent),
        );
    }

    // Getter Funs

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

    public fun package_version(): u64 { PACKAGE_VERSION }

    public fun duration(): u64 { ONE_HOUR }

    // Friend Funs

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

    public(package) fun assert_valid_config_version(
        config: &BucketPointConfig,
    ) {
        if (!config.valid_versions.contains(&package_version()))
            err_invalid_package_version();
    }

    // Test-only Funs

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}