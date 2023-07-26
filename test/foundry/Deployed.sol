// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity >=0.5.1;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

import {LendingRegistry} from "contracts/LendingRegistry.sol";

import {Dai} from "./Dai.t.sol";

// TODO: move this to useful
contract Logging is Test {
    bool public logging = false;
    bytes16 private constant _SYMBOLS = "0123456789abcdef";

    function setLogging(bool newVal) public {
        logging = newVal;
    }

    function toString(uint256 value, uint256 decimals) public pure returns (string memory result) {
        // calculate the length of the result
        uint256 length;
        for (uint256 j = value; j != 0; j /= 10) {
            length++;
        }
        if (decimals > 0) {
            if (length > decimals) {
                length++; // for the decimal point
            } else {
                length = decimals + 2; // "0." + "00..." prefix
            }
        }

        string memory buffer = new string(length);
        uint256 ptr;
        /// @solidity memory-safe-assembly
        assembly {
            ptr := add(buffer, add(32, length))
        }
        uint256 digit = 0;
        while (true) {
            ptr--;
            if (decimals > 0 && digit == decimals) {
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, 46)
                }
                ptr--;
                digit++;
            }
            digit++;
            /// @solidity memory-safe-assembly
            assembly {
                mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
            }
            value /= 10;
            if (digit == length) break;
        }
        return buffer;
    }

    constructor() {
        // logging = !streq(vm.envString("LOG"), "");
        // if (logging) console.log("LOG = '%s'", vm.envString("LOG"));
    }
}

contract Deployed {
    // Dai maker
    // address public constant DAIOWNER = address(0xdDb108893104dE4E1C6d0E47c42237dB4E617ACc);

    // deployed addresses for BAO
    address public constant OWNER = address(0xFC69e0a5823E2AfCBEb8a35d33588360F1496a00);
    // Recipe https://etherscan.io/address/0xac0fE9F363c160c281c81DdC49d0AA8cE04C02Eb
    address public constant RECIPE = address(0xac0fE9F363c160c281c81DdC49d0AA8cE04C02Eb);
    // Basket Registry https://etherscan.io/address/0x51801401e1f21c9184610b99B978D050a374566E
    address public constant BASKETREGISTRY = address(0x51801401e1f21c9184610b99B978D050a374566E);
    // Lending Registry https://etherscan.io/address/0x08a2b7D713e388123dc6678168656659d297d397
    address public constant LENDINGREGISTRY = address(0x08a2b7D713e388123dc6678168656659d297d397);
    // Basket Factory https://etherscan.io/address/0xe1e7634Cd2AED55C6aAA704299E735987f372b70
    address public constant BASKETFACTORY = address(0xe1e7634Cd2AED55C6aAA704299E735987f372b70);
    // AAVELendingStrategy	https://etherscan.io/address/0xD67730986FC37d55eCF5cCA0d2D854f4FCf5d876
    address public constant LENDINGLOGICAAVE = address(0xD67730986FC37d55eCF5cCA0d2D854f4FCf5d876);
    // CompoundLendingStrategy https://etherscan.io/address/0x5822D781503676b6a927eA841039465193CA213a
    address public constant LENDINGLOGICCOMPOUND = address(0x5822D781503676b6a927eA841039465193CA213a);
    // bSTBL https://etherscan.io/address/0x5ee08f40b637417bcC9d2C51B62F4820ec9cF5D8
    address public constant BSTBL = address(0x5ee08f40b637417bcC9d2C51B62F4820ec9cF5D8);
    // bSTBL LendingManager https://etherscan.io/address/0x5C0AfEf620f512e2FA65C765A72fa46f9A41C6BD
    address public constant BSTBLLENDINGMANAGER = address(0x5C0AfEf620f512e2FA65C765A72fa46f9A41C6BD);
    // protocols
    bytes32 public constant PROTOCOLCOMPOUND = 0x0000000000000000000000000000000000000000000000000000000000000001;
    bytes32 public constant PROTOCOLAAVE = 0x0000000000000000000000000000000000000000000000000000000000000002;
    bytes32 public constant PROTOCOLKASHI = 0x0000000000000000000000000000000000000000000000000000000000000003;

    struct Token {
        string name;
        address addr;
    }

    // underlyings
    Token public FEI = Token("FEI", address(0x000000000000000000000000956f47f50a910163d8bf957cf5846d573e7f87ca));
    Token public DAI = Token("DAI", address(0x0000000000000000000000006b175474e89094c44da98b954eedeac495271d0f));
    Token public RAI = Token("RAI", address(0x00000000000000000000000003ab458634910aad20ef5f1c8ee96f1d6ac54919));
    Token public USDC = Token("USDC", address(0x000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48));
    Token public FRAX = Token("FRAX", address(0x000000000000000000000000853d955acef822db058eb8505911ed77f175b99e));
    Token public COMP = Token("COMP", address(0x000000000000000000000000c00e94cb662c3520282e6f5717214004a7f26888));
    Token public YFI = Token("YFI", address(0x0000000000000000000000000bc529c00c6401aef6d220be8c6ea1667f6ad93e));
    Token public CRV = Token("CRV", address(0x000000000000000000000000d533a949740bb3306d119cc777fa900ba034cd52));
    Token public SUSHI = Token("SUSHI", address(0x0000000000000000000000006b3595068778dd592e39a122f4f5a5cf09c90fe2));
    Token public AAVE = Token("AAVE", address(0x0000000000000000000000007fc66500c84a76ad7e9c93437bfc5ac33e2ddae9));
    Token public SUSD = Token("sUSD", address(0x00000000000000000000000057ab1ec28d129707052df4df418d58a2d46d5f51));

    Token public LUSD = Token("LUSD", address(0x5f98805A4E8be255a32880FDeC7F6728C6568bA0));

    // compound
    Token public CDAI = Token("cDAI", address(0x0000000000000000000000005d3a536e4d6dbd6114cc1ead35777bab948e3643)); // 1
    Token public CCOMP = Token("cCOMP", address(0x00000000000000000000000070e36f6bf80a52b3b46b3af8e106cc0ed743e8e4)); // 1
    Token public CAAVE = Token("cAAVE", address(0x000000000000000000000000e65cdb6479bac1e22340e4e755fae7e509ecd06c)); // 1
    // address public constant CUSDC = address(0x39AA39c021dfbaE8faC545936693aC917d5E7563);

    // aave
    Token public AFEI = Token("aFEI", address(0x000000000000000000000000683923db55fead99a79fa01a27eec3cb19679cc3)); //2
    Token public ARAI = Token("aRAI", address(0x000000000000000000000000c9bc48c72154ef3e5425641a3c747242112a46af)); // 2
    Token public AUSDC = Token("aUSDC", address(0x000000000000000000000000bcca60bb61934080951369a648fb03df4f96263c)); // 2
    Token public AFRAX = Token("aFRAX", address(0x000000000000000000000000d4937682df3c8aef4fe912a96a74121c0829e664)); // 2
    Token public AYFI = Token("aYFI", address(0x0000000000000000000000005165d24277cd063f5ac44efd447b27025e888f37)); // 2
    Token public ACRV = Token("aCRV", address(0x0000000000000000000000008dae6cb04688c62d939ed9b68d32bc62e49970b1)); // 2
    Token public ADAI = Token("aDAI", address(0x000000000000000000000000028171bca77440897b824ca71d1c56cac55b68a3)); // 2
    Token public ASUSD = Token("aSUSD", address(0x0000000000000000000000006c5024cd4f8a59110119c56f8933403a539555eb)); // 2

    // kashi
    Token public XSUSHI = Token("xSUSHI", address(0x0000000000000000000000008798249c2e607446efb7ad49ec89dd1865ff4272)); // 3

    // yearn
    Token public YVLUSD = Token("yvLUSD", address(0x378cb52b00F9D0921cb46dFc099CFf73b42419dC)); // 4
    // address public YVLUSDTRACKER = 0x378cb52b00F9D0921cb46dFc099CFf73b42419dC; // not sure if this is needed
    address public YVLUSDSTRATEGY1 = 0xFf72f7C5f64ec2fd79B57d1A69C3311C1bB3EEF1;
}

contract ChainFork is Logging, Deployed {
    uint256 public mainnetFork;
    LendingRegistry public lendingRegistry;

    constructor() {
        lendingRegistry = LendingRegistry(Deployed.LENDINGREGISTRY);
        if (logging) console.log("MAINNET_RPC_URL=", vm.envString("MAINNET_RPC_URL"));
        mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
        vm.selectFork(mainnetFork);
        assertEq(vm.activeFork(), mainnetFork);
    }
}

contract ChainState is ChainFork {
    uint256 public constant BLOCKNUMBER = 17697898;

    constructor() {
        vm.rollFork(BLOCKNUMBER);
        assertEq(block.number, BLOCKNUMBER);
    }
}
