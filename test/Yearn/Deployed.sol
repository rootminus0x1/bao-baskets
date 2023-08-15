// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity >=0.5.1;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

import {LendingRegistry} from "src/LendingRegistry.sol";

import {ChainState} from "./ChainState.sol";

//import {Dai} from "./Dai.t.sol";

library Deployed {
    // Dai maker
    // address public constant DAIOWNER = 0xdDb108893104dE4E1C6d0E47c42237dB4E617ACc;

    // deployed addresses for BAO
    address public constant OWNER = 0xFC69e0a5823E2AfCBEb8a35d33588360F1496a00;
    // Recipe https://etherscan.io/address/0xac0fE9F363c160c281c81DdC49d0AA8cE04C02Eb
    address public constant RECIPE = 0xac0fE9F363c160c281c81DdC49d0AA8cE04C02Eb;
    // Basket Registry https://etherscan.io/address/0x51801401e1f21c9184610b99B978D050a374566E
    address public constant BASKETREGISTRY = 0x51801401e1f21c9184610b99B978D050a374566E;
    // Lending Registry https://etherscan.io/address/0x08a2b7D713e388123dc6678168656659d297d397
    address public constant LENDINGREGISTRY = 0x08a2b7D713e388123dc6678168656659d297d397;
    // Basket Factory https://etherscan.io/address/0xe1e7634Cd2AED55C6aAA704299E735987f372b70
    address public constant BASKETFACTORY = 0xe1e7634Cd2AED55C6aAA704299E735987f372b70;
    // AAVELendingStrategy	https://etherscan.io/address/0xD67730986FC37d55eCF5cCA0d2D854f4FCf5d876
    address public constant LENDINGLOGICAAVE = 0xD67730986FC37d55eCF5cCA0d2D854f4FCf5d876;
    // CompoundLendingStrategy https://etherscan.io/address/0x5822D781503676b6a927eA841039465193CA213a
    address public constant LENDINGLOGICCOMPOUND = 0x5822D781503676b6a927eA841039465193CA213a;
    // bSTBL https://etherscan.io/address/0x5ee08f40b637417bcC9d2C51B62F4820ec9cF5D8
    address public constant BSTBL = 0x5ee08f40b637417bcC9d2C51B62F4820ec9cF5D8;
    // bSTBL LendingManager https://etherscan.io/address/0x5C0AfEf620f512e2FA65C765A72fa46f9A41C6BD
    address public constant BSTBLLENDINGMANAGER = 0x5C0AfEf620f512e2FA65C765A72fa46f9A41C6BD;
    // protocols
    bytes32 public constant PROTOCOLCOMPOUND = 0x0000000000000000000000000000000000000000000000000000000000000001;
    bytes32 public constant PROTOCOLAAVE = 0x0000000000000000000000000000000000000000000000000000000000000002;
    bytes32 public constant PROTOCOLKASHI = 0x0000000000000000000000000000000000000000000000000000000000000003;

    // underlyings
    address public constant FEI = 0x956F47F50A910163D8BF957Cf5846D573E7f87CA;
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant RAI = 0x03ab458634910AaD20eF5f1C8ee96F1D6ac54919;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
    address public constant COMP = 0xc00e94Cb662C3520282E6f5717214004A7f26888;
    address public constant YFI = 0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e;
    address public constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;
    address public constant SUSHI = 0x6B3595068778DD592e39A122f4f5a5cF09C90fE2;
    address public constant AAVE = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
    address public constant SUSD = 0x57Ab1ec28D129707052df4dF418D58a2D46d5f51;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant TUSD = 0x0000000000085d4780B73119b644AE5ecd22b376;

    address public constant LUSD = 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0;

    // compound
    address public constant CDAI = 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643; // 1
    address public constant CCOMP = 0x70e36f6BF80a52b3B46b3aF8e106CC0ed743E8e4; // 1
    address public constant CAAVE = 0xe65cdB6479BaC1e22340E4E755fAE7E509EcD06c; // 1
    // address public constant CUSDC = 0x39AA39c021dfbaE8faC545936693aC917d5E7563;

    // aave
    address public constant AFEI = 0x683923dB55Fead99A79Fa01A27EeC3cB19679cC3; //2
    address public constant ARAI = 0xc9BC48c72154ef3e5425641a3c747242112a46AF; // 2
    address public constant AUSDC = 0xBcca60bB61934080951369a648Fb03DF4F96263C; // 2
    address public constant AFRAX = 0xd4937682df3C8aEF4FE912A96A74121C0829E664; // 2
    address public constant AYFI = 0x5165d24277cD063F5ac44Efd447B27025e888f37; // 2
    address public constant ACRV = 0x8dAE6Cb04688C62d939ed9B68d32Bc62e49970b1; // 2
    address public constant ADAI = 0x028171bCA77440897B824Ca71D1c56caC55b68A3; // 2
    address public constant ASUSD = 0x6C5024Cd4F8A59110119C56f8933403A539555EB; // 2

    // kashi
    address public constant XSUSHI = 0x8798249c2E607446EfB7Ad49eC89dD1865Ff4272; // 3

    // yearn
    address public constant YVLUSD = 0x378cb52b00F9D0921cb46dFc099CFf73b42419dC; // 4
    // address public constant YVLUSDSTRATEGY1 = 0xFf72f7C5f64ec2fd79B57d1A69C3311C1bB3EEF1;
    address public constant YVUSDC = 0xa354F35829Ae975e850e23e9615b11Da1B3dC4DE;
    address public constant YVDAI = 0xdA816459F1AB5631232FE5e97a05BBBb94970c95;
    address public constant YVUSDT = 0x3B27F92C0e212C671EA351827EDF93DB27cc0c65;
    address public constant YVTUSD = 0xFD0877d9095789cAF24c98F7CCe092fa8E120775;

    uint256 public constant blockWithCompoundAaveKashi = 17698530; // Jul-15-2023 11:36:35 AM +UTC
}

contract ChainStateLending is ChainState {
    LendingRegistry public lendingRegistry;

    constructor() {
        rollForkTo(Deployed.blockWithCompoundAaveKashi);
        lendingRegistry = LendingRegistry(Deployed.LENDINGREGISTRY);
    }
}
