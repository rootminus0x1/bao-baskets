// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity ^0.7.1;

contract Deployed {
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
    address public constant AAVELENDINGSTRATEGY = address(0xD67730986FC37d55eCF5cCA0d2D854f4FCf5d876);
    // CompoundLendingStrategy https://etherscan.io/address/0x5822D781503676b6a927eA841039465193CA213a
    address public constant COMPOUNDLENDINGSTRATEGY = address(0x5822D781503676b6a927eA841039465193CA213a);
    // bSTBL https://etherscan.io/address/0x5ee08f40b637417bcC9d2C51B62F4820ec9cF5D8
    address public constant BSTBL = address(0x5ee08f40b637417bcC9d2C51B62F4820ec9cF5D8);
    // bSTBL LendingManager https://etherscan.io/address/0x5C0AfEf620f512e2FA65C765A72fa46f9A41C6BD
    address public constant BSTBLLENDINGMANAGER = address(0x5C0AfEf620f512e2FA65C765A72fa46f9A41C6BD);
    // protocols
    bytes32 public constant COMPOUNDPROTOCOL = 0x0000000000000000000000000000000000000000000000000000000000000001;
    bytes32 public constant AAVEPROTOCOL = 0x0000000000000000000000000000000000000000000000000000000000000002;
    bytes32 public constant SUSHIPROTOCOL = 0x0000000000000000000000000000000000000000000000000000000000000003;
    bytes32 public constant YEARNPROTOCOL = 0x0000000000000000000000000000000000000000000000000000000000000004;

    address public constant CUSDC = address(0x39AA39c021dfbaE8faC545936693aC917d5E7563);

    struct Token {
        string name;
        address addr;
    }

    Token public AFEI = Token("aFEI", address(0x000000000000000000000000683923db55fead99a79fa01a27eec3cb19679cc3)); //2
    Token public CDAI = Token("cDAI", address(0x0000000000000000000000005d3a536e4d6dbd6114cc1ead35777bab948e3643)); // 1
    Token public ARAI = Token("aRAI", address(0x000000000000000000000000c9bc48c72154ef3e5425641a3c747242112a46af)); // 2
    Token public AUSDC = Token("aUSDC", address(0x000000000000000000000000bcca60bb61934080951369a648fb03df4f96263c)); // 2
    Token public AFRAX = Token("aFRAX", address(0x000000000000000000000000d4937682df3c8aef4fe912a96a74121c0829e664)); // 2
    Token public CCOMP = Token("cCOMP", address(0x00000000000000000000000070e36f6bf80a52b3b46b3af8e106cc0ed743e8e4)); // 1
    Token public AYFI = Token("aYFI", address(0x0000000000000000000000005165d24277cd063f5ac44efd447b27025e888f37)); // 2
    Token public ACRV = Token("aCRV", address(0x0000000000000000000000008dae6cb04688c62d939ed9b68d32bc62e49970b1)); // 2
    Token public XSUSHI = Token("xSUSHI", address(0x0000000000000000000000008798249c2e607446efb7ad49ec89dd1865ff4272)); // 3
    Token public CAAVE = Token("cAAVE", address(0x000000000000000000000000e65cdb6479bac1e22340e4e755fae7e509ecd06c)); // 1
    Token public ADAI = Token("aDAI", address(0x000000000000000000000000028171bca77440897b824ca71d1c56cac55b68a3)); // 2
    Token public ASUSD = Token("aSUSD", address(0x0000000000000000000000006c5024cd4f8a59110119c56f8933403a539555eb)); // 2

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

    /*
    // LendingRegistry: mapping(address => bytes32) public wrappedToProtocol;
    struct WrappedToProtocol {
        address wrapped;
        bytes32 protocol;
    }

    WrappedToProtocol[] public wrappedToProtocol = [
        WrappedToProtocol(AFEI.addr, AAVEPROTOCOL),
        WrappedToProtocol(CDAI.addr, COMPOUNDPROTOCOL),
        WrappedToProtocol(ARAI.addr, AAVEPROTOCOL),
        WrappedToProtocol(AUSDC.addr, AAVEPROTOCOL),
        WrappedToProtocol(AFRAX.addr, AAVEPROTOCOL),
        WrappedToProtocol(CCOMP.addr, COMPOUNDPROTOCOL),
        WrappedToProtocol(AYFI.addr, AAVEPROTOCOL),
        WrappedToProtocol(ACRV.addr, AAVEPROTOCOL),
        WrappedToProtocol(XSUSHI.addr, SUSHIPROTOCOL),
        WrappedToProtocol(CAAVE.addr, COMPOUNDPROTOCOL),
        WrappedToProtocol(ADAI.addr, AAVEPROTOCOL),
        WrappedToProtocol(ASUSD.addr, AAVEPROTOCOL)
    ];

    // LendingRegistry: mapping(address => address) public wrappedToUnderlying;
    struct WrappedToUnderlying {
        Token wrapped;
        Token underlying;
    }

    WrappedToUnderlying[] public wrappedToUnderlying = [
        WrappedToUnderlying(AFEI, FEI),
        WrappedToUnderlying(CDAI, DAI),
        WrappedToUnderlying(ARAI, RAI),
        WrappedToUnderlying(AUSDC, USDC),
        WrappedToUnderlying(AFRAX, FRAX),
        WrappedToUnderlying(CCOMP, COMP),
        WrappedToUnderlying(AYFI, YFI),
        WrappedToUnderlying(ACRV, CRV),
        WrappedToUnderlying(XSUSHI, SUSHI),
        WrappedToUnderlying(CAAVE, AAVE),
        WrappedToUnderlying(ADAI, DAI),
        WrappedToUnderlying(ASUSD, SUSD)
    ];

    // LendingRegistry: mapping(address => mapping(bytes32 => address)) public underlyingToProtocolWrapped;
    struct ProtocolToWrapped {
        bytes32 protocol;
        Token wrapped;
    }

    struct UnderlyingToProtocolWrapped {
        Token underlying;
        ProtocolToWrapped[] protocolToWrapped;
    }

    UnderlyingToProtocolWrapped[] public underlyingToProtocolWrapped = [
        UnderlyingToProtocolWrapped(RAI, new ProtocolToWrapped[](0)), // (2, ARAI)
        UnderlyingToProtocolWrapped(DAI, new ProtocolToWrapped[](0)), // (1, CDAI), (2, ADAI)
        UnderlyingToProtocolWrapped(FEI, new ProtocolToWrapped[](0)), // (2, AFEI)
        UnderlyingToProtocolWrapped(USDC, new ProtocolToWrapped[](0)), // (2, AUSDC)
        UnderlyingToProtocolWrapped(FRAX, new ProtocolToWrapped[](0)), // (2, AFRAX)
        UnderlyingToProtocolWrapped(COMP, new ProtocolToWrapped[](0)), // (1, CCOMP)
        UnderlyingToProtocolWrapped(YFI, new ProtocolToWrapped[](0)), // (2, AYFI)
        UnderlyingToProtocolWrapped(CRV, new ProtocolToWrapped[](0)), // (2, ACRV)
        UnderlyingToProtocolWrapped(SUSHI, new ProtocolToWrapped[](0)), // (3, XSUSHI)
        UnderlyingToProtocolWrapped(AAVE, new ProtocolToWrapped[](0)), // (1, CAAVE)
        UnderlyingToProtocolWrapped(SUSD, new ProtocolToWrapped[](0)) // (2, ASUSD)
    ];

    // LendingRegistry: mapping(bytes32 => address) public protocolToLogic;
    struct ProtocolToLogic {
        bytes32 protocol;
        address logic;
    }

    ProtocolToLogic[] protocolToLogic = [
        ProtocolToLogic(COMPOUNDPROTOCOL, address(0x0000000000000000000000005822d781503676b6a927ea841039465193ca213a)),
        ProtocolToLogic(AAVEPROTOCOL, address(0x000000000000000000000000d67730986fc37d55ecf5cca0d2d854f4fcf5d876)),
        ProtocolToLogic(SUSHIPROTOCOL, address(0x000000000000000000000000fdbb1009beff807336c0e34e88bb9ff0fe72f849))
    ];

    constructor() {
        // fill out the arrays in underLyingToProtocolWrapped from wrappedToUnderlying and wrappedToProtcol
        for (uint256 u = 0; u < underlyingToProtocolWrapped.length; u++) {
            address underlying = underlyingToProtocolWrapped[u].underlying.addr;
            for (uint256 wu = 0; wu < wrappedToUnderlying.length; wu++) {
                if (underlying == wrappedToUnderlying[wu].underlying.addr) {
                    address wrapped = wrappedToUnderlying[wu].wrapped.addr;
                    bytes32 protocol = 0;
                    for (uint256 wp = 0; wp < wrappedToProtocol.length; wp++) {
                        if (wrapped == wrappedToProtocol[wp].wrapped) {
                            protocol = bytes32(wrappedToProtocol[wp].protocol);
                            break;
                        }
                    }
                    require(protocol == 0, "no protocol found for wrapped");
                    underlyingToProtocolWrapped[u].protocolToWrapped.push(
                        ProtocolToWrapped(protocol, wrappedToUnderlying[wu].wrapped)
                    );
                }
            }
        }
    }
    */
}
