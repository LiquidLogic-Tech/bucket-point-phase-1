module bucket_point_phase1::lst_proof_rule {

    // Dependencies

    use std::ascii::{String};
    use sui::sui::SUI;
    use sui::clock::{Clock};
    use liquidlink_locker::asset_locker::{Self, AssetLocker};
    use flask::float;
    use bucket_point_phase1::config::{
        Self, BucketPointConfig, BucketPointCap, BucketPointPhase1 as BPP1
    };
    use bucket_protocol::buck::{BucketProtocol};
    use strap_fountain::fountain::{Self, Fountain, StakeProof};

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
        protocol: &BucketProtocol,
        clock: &Clock,
        proof: StakeProof<T, SUI>,
        ctx: &mut TxContext,
    ) {
        config.assert_valid_config_version();
        let (weight, action) = config.get_locker_params(locker);
        let debt = fountain::get_raw_debt<T>(protocol, proof.strap_address());
        let point = float::from(debt).mul(weight).floor() as u256;
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
        protocol: &BucketProtocol,
        fountain: &mut Fountain<T, SUI>,
        clock: &Clock,
        index: u64,
        ctx: &mut TxContext,
    ): StakeProof<T, SUI> {
        config.assert_valid_config_version();
        let w = &config::witness();
        let owner = ctx.sender();
        let proof = borrow_asset(w, locker, owner, index);
        let strap_address = proof.strap_address();
        let debt_amount = if (fountain::bottle_exists<T>(protocol, strap_address)) {
            fountain::get_raw_debt<T>(protocol, strap_address)
        } else {
            let (_, _, debt_amount) = fountain.liquidate_with_info<T, SUI>(
                protocol, clock, strap_address, ctx,
            );
            debt_amount
        };
        unlock_internal(config, locker, clock, index, owner, debt_amount, ctx)
    }
    
    public fun liquidate<T>(
        config: &BucketPointConfig,
        locker: &mut AssetLocker<StakeProof<T, SUI>, BPP1>,
        protocol: &BucketProtocol,
        fountain: &mut Fountain<T, SUI>,
        clock: &Clock,
        owner: address,
        ctx: &mut TxContext,
    ) {
        config.assert_valid_config_version();
        let w = &config::witness();
        let mut is_not_empty = !locker.assets_of(w, owner).is_empty();
        while (is_not_empty) {
            let proof = &locker.assets_of(w, owner)[0];
            // let proof = &proofs[0];
            let strap_address = proof.strap_address();
            let (is_liquidated, _, debt_amount) = fountain.liquidate_with_info<T, SUI>(
                protocol, clock, strap_address, ctx,
            );
            if (is_liquidated) {
                let proof = unlock_internal(
                    config, locker, clock, 0, owner, debt_amount, ctx,
                );
                transfer::public_transfer(proof, owner);
            };
            is_not_empty = !locker.assets_of(w, owner).is_empty();
        };
    }

    // Internal Funs

    fun borrow_asset<T>(
        witness: &BPP1,
        locker: &AssetLocker<StakeProof<T, SUI>, BPP1>,
        owner: address,
        index: u64,
    ): &StakeProof<T, SUI> {
        let proofs = locker.assets_of(witness, owner);
        if (index >= proofs.length()) err_index_out_of_range();
        proofs.borrow(index)
    }

    fun unlock_internal<T>(
        config: &BucketPointConfig,
        locker: &mut AssetLocker<StakeProof<T, SUI>, BPP1>,
        clock: &Clock,
        index: u64,
        owner: address,
        debt_amount: u64,
        ctx: &mut TxContext,
    ): StakeProof<T, SUI> {
        let w = &mut config::witness();
        let proofs = locker.assets_of(w, owner);
        if (index >= proofs.length()) err_index_out_of_range();
        let (weight, action) = config.get_locker_params(locker);
        let point = float::from(debt_amount).mul(weight).floor() as u256;
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
