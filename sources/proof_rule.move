module bucket_point_phase1::proof_rule {

    // Dependencies

    use std::ascii::{String};
    use sui::sui::SUI;
    use sui::clock::{Clock};
    use liquidlink_locker::asset_locker::{Self, AssetLocker};
    use flask::float;
    use bucket_point_phase1::config::{
        Self, BucketPointConfig, BucketPointCap, BucketPointPhase1 as BPP1
    };
    use bucket_fountain::fountain_core::{StakeProof};

    // Errors

    const EIndexOutOfRange: u64 = 0;
    fun err_index_out_of_range() { abort EIndexOutOfRange }

    // Admin Funs

    public fun create_locker<T>(
        config: &mut BucketPointConfig,
        _cap: &BucketPointCap,
        weight_percent: u64,
        action_name: String,
        ctx: &mut TxContext,
    ) {
        config.assert_valid_config_version();
        let locker_id = asset_locker::create<StakeProof<T, SUI>, BPP1>(
            &config::witness(), ctx,
        );
        config.insert(locker_id, weight_percent, action_name);
    }

    // Public Funs

    public fun lock<T>(
        config: &BucketPointConfig,
        locker: &mut AssetLocker<StakeProof<T, SUI>, BPP1>,
        clock: &Clock,
        proof: StakeProof<T, SUI>,
        ctx: &mut TxContext,
    ) {
        config.assert_valid_config_version();
        let (weight, action) = config.get_locker_params(locker);
        let amount = proof.get_proof_stake_amount();
        let point = float::from(amount).mul(weight).floor() as u256;
        locker.lock(
            &mut config::witness(),
            ctx.sender(),
            proof,
            action,
            point,
            config::duration(),
            clock,
            ctx,
        );
    }

    public fun unlock<T>(
        config: &BucketPointConfig,
        locker: &mut AssetLocker<StakeProof<T, SUI>, BPP1>,
        clock: &Clock,
        index: u64,
        ctx: &mut TxContext,
    ): StakeProof<T, SUI> {
        config.assert_valid_config_version();
        let w = &mut config::witness();
        let owner = ctx.sender();
        let proofs = locker.assets_of(w, owner);
        if (index >= proofs.length()) err_index_out_of_range();
        let amount = proofs[index].get_proof_stake_amount();
        let (weight, action) = config.get_locker_params(locker);
        let point = float::from(amount).mul(weight).floor() as u256;
        locker.unlock(
            w,
            owner,
            index,
            action,
            point,
            config::duration(),
            clock,
            ctx,
        )    
    }
}
