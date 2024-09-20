#[test_only]
#[allow(unused)]
module bucket_point_phase1::test_balance_rule {
    use std::ascii::{Self, string, String};
    use std::u64;

    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use sui::clock::{Self, Clock, increment_for_testing as add_time, set_for_testing as set_time};
    use sui::coin::{ Self, Coin, TreasuryCap, CoinMetadata, mint_for_testing as mint, burn_for_testing as burn};
    use sui::balance::{ Self, Balance, create_for_testing as create, destroy_for_testing as destroy};
    use sui::math;

    // liquidlink_protocol
    use liquidlink_protocol::{
        profile::{Self, ProfileRegistry, Profile, AdmincCap},
        point::{Self, AddPointRequest, SubPointRequest, StakePointRequest, UnstakePointRequest, PointDashBoard},
        constant::{point_updater},
    };

    // bucket_point_phase1
    use liquidlink_locker::{
        asset_locker::{Self, AssetLocker},
        balance_locker,
    };
    use bucket_point_phase1::{
        config::{Self, BucketPointCap, BucketPointConfig, BucketPointPhase1},
        balance_rule,
    };

    /// Witness

    // Mock-up assets
    public struct SBUCK has drop {}

    // utils
    fun people(): (address, address, address) {
        (point_updater(), @0xB, @0xC)
    }

    public fun sui_1(): u64 { u64::pow(10, 9) }
    public fun sui_1K(): u64 { u64::pow(10, 12) }
    public fun sui_1M(): u64 { u64::pow(10, 15) }
    public fun sui_100M(): u64 { u64::pow(10, 17) }


    #[test]
    fun test_sbuck_point() {
        let (mut scenario, mut clock) = setup();
        let s = &mut scenario;
        let (updater, staker, _) = people();

        s.next_tx(updater);
        {
            let mut config = s.take_shared<BucketPointConfig>();
            let cap = s.take_from_sender<BucketPointCap>();
            balance_rule::create_locker<SBUCK>(
                &mut config, &cap, 110, string(b"ST_SBUCK"), s.ctx(),
            );
            s.return_to_sender(cap);
            test::return_shared(config);
        };

        s.next_tx(updater);
        {
            let locker = test::take_shared<AssetLocker<Balance<SBUCK>, BucketPointPhase1>>(s);
            assert!(asset_locker::has_assets(&locker, updater) == false, 404);
            test::return_shared(locker);

        };

        let mut deposit = sui_1K();
        let mut acc_points = 0;

        // lock SBUCK and stake the points for Staker
        s.next_tx(staker);
        {
            let mut dashboard = test::take_shared<PointDashBoard<BucketPointPhase1>>(s);
            let mut locker = test::take_shared<AssetLocker<Balance<SBUCK>, BucketPointPhase1>>(s);
            let config = s.take_shared<BucketPointConfig>();

            balance_rule::deposit(
                &config, &mut locker, &clock, create<SBUCK>(deposit), ctx(s),
            );
            
            assert!(balance_locker::owner_locked_balance(&locker, staker) == deposit, 404);
            assert!(dashboard.get_user_info_points(staker, &clock) == 0, 404);
            assert!(dashboard.get_user_info_point_by_action(staker, string(b"ST_SBUCK"), &clock) == 0, 404);

            test::return_shared(locker);
            test::return_shared(dashboard);
            test::return_shared(config);
        };

        // UPDATER update the point
        s.next_tx(updater);
        {
            let mut dashboard = test::take_shared<PointDashBoard<BucketPointPhase1>>(s);
            let cap = test::take_from_sender<AdmincCap>(s);
            let req = test::take_from_sender<StakePointRequest<BucketPointPhase1>>(s);

            dashboard.stake_point_by_admin(&cap, req);
    
            test::return_to_sender(s, cap);
            test::return_shared(dashboard);
        };

        // past 1 day
        clock.add_time(86400_000);

        s.next_tx(staker);
        {
            let dashboard = test::take_shared<PointDashBoard<BucketPointPhase1>>(s);
                
            let info = dashboard.get_user_info(staker);
            acc_points = 26_400_000_000_000;
            assert!(dashboard.get_user_info_points(staker, &clock) == acc_points, 404);
            assert!(dashboard.get_user_info_point_by_action(staker, string(b"ST_SBUCK"), &clock) == acc_points, 404);

            test::return_shared(dashboard);
        };

        // withdraw half balance out
        s.next_tx(staker);{
            let mut dashboard = test::take_shared<PointDashBoard<BucketPointPhase1>>(s);
            let mut locker = test::take_shared<AssetLocker<Balance<SBUCK>, BucketPointPhase1>>(s);
            let config = s.take_shared<BucketPointConfig>();

            let sbuck = balance_rule::withdraw(
                &config, &mut locker, &clock, deposit/2, ctx(s),
            );

            assert!(destroy(sbuck) == deposit/2, 404);
            assert!(balance_locker::owner_locked_balance(&locker, staker) == deposit/2, 404);
            assert!(dashboard.get_user_info_points(staker, &clock) == acc_points, 404);
            assert!(dashboard.get_user_info_point_by_action(staker, string(b"ST_SBUCK"), &clock) == acc_points, 404);

            test::return_shared(locker);
            test::return_shared(dashboard);
            test::return_shared(config);
        };

        s.next_tx(updater);{
            let mut dashboard = test::take_shared<PointDashBoard<BucketPointPhase1>>(s);
            let cap = test::take_from_sender<AdmincCap>(s);
            let req = test::take_from_sender<UnstakePointRequest<BucketPointPhase1>>(s);

            dashboard.unstake_point_by_admin(&cap, req);
    
            test::return_to_sender(s, cap);
            test::return_shared(dashboard);
        };

        // past 1 week
        clock.add_time(7 * 86400_000);

        s.next_tx(staker);{
            let dashboard = test::take_shared<PointDashBoard<BucketPointPhase1>>(s);
                
            let info = dashboard.get_user_info(staker);
            std::debug::print(&dashboard.get_user_info_points(staker, &clock));
            acc_points = acc_points + 7 * 13_200_000_000_000;
            assert!(dashboard.get_user_info_points(staker, &clock) == acc_points, 404);
            assert!(dashboard.get_user_info_point_by_action(staker, string(b"ST_SBUCK"), &clock) == acc_points, 404);
            assert!(dashboard.get_user_info_point_by_action(staker, string(b"foo"), &clock) == 0, 404);

            test::return_shared(dashboard);
        };

        // withdraw all balance
        s.next_tx(staker);{
            let mut dashboard = test::take_shared<PointDashBoard<BucketPointPhase1>>(s);
            let mut locker = test::take_shared<AssetLocker<Balance<SBUCK>, BucketPointPhase1>>(s);
            let config = s.take_shared<BucketPointConfig>();

            let total_balance = balance_locker::owner_locked_balance(&locker, staker);
            let sbuck = balance_rule::withdraw(
                &config, &mut locker, &clock, total_balance, ctx(s),
            );
            
            assert!(destroy(sbuck) == deposit/2, 404);
            assert!(balance_locker::owner_locked_balance(&locker, staker) == 0, 404);
            assert!(dashboard.get_user_info_points(staker, &clock) == acc_points, 404);
            assert!(dashboard.get_user_info_point_by_action(staker, string(b"ST_SBUCK"), &clock) == acc_points, 404);

            test::return_shared(locker);
            test::return_shared(dashboard);
            test::return_shared(config);
        };

        s.next_tx(updater);{
            let mut dashboard = test::take_shared<PointDashBoard<BucketPointPhase1>>(s);
            let cap = test::take_from_sender<AdmincCap>(s);
            let req = test::take_from_sender<UnstakePointRequest<BucketPointPhase1>>(s);

            dashboard.unstake_point_by_admin(&cap, req);
    
            test::return_to_sender(s, cap);
            test::return_shared(dashboard);
        };

        // past 1 week. points should remain
        clock.add_time(7 * 86400 * 1000);

        s.next_tx(staker);{
            let dashboard = test::take_shared<PointDashBoard<BucketPointPhase1>>(s);
                
            let info = dashboard.get_user_info(staker);
            assert!(dashboard.get_user_info_points(staker, &clock) == acc_points, 404);
            assert!(dashboard.get_user_info_point_by_action(staker, string(b"ST_SBUCK"), &clock) == acc_points, 404);
            assert!(dashboard.get_user_info_point_by_action(staker, string(b"foo"), &clock) == 0, 404);

            test::return_shared(dashboard);
        };

        clock.destroy_for_testing();
        scenario.end();
    }

    fun setup(): (Scenario, Clock) {
        let (updater, _, _) = people();
        let mut scenario = test::begin(updater);
        let s = &mut scenario;
        let mut clock = clock::create_for_testing(ctx(s));

        profile::init_for_testing(ctx(s));

        s.next_tx(updater);
        config::init_for_testing(s.ctx());

        // register_point_module
        s.next_tx(updater);
        {
            let mut reg = test::take_shared<ProfileRegistry>(s);
            let cap = test::take_from_sender<AdmincCap>(s);
        
            profile::register_point_module<BucketPointPhase1>(&cap, &mut reg);
            profile::new_point_dashboard<BucketPointPhase1>(&cap, &mut reg, ctx(s));

            test::return_shared(reg);
            test::return_to_sender(s, cap);
        };

        (scenario, clock)
    }
}
