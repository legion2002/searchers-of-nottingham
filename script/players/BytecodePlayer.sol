// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import '~/game/IGame.sol';

// A player contract that just wraps an opaque bytecode implementation,
// e.g., if you decrypt another player's code from a prior season.
contract BytecodePlayer is IPlayer {

    constructor(IGame game, uint8 playerIdx, uint8 playerCount, uint8 assetCount) {
        bytes memory bytecodeWithArgs = bytes.concat(
            _getBytecode(),
            abi.encode(game, playerIdx, playerCount, assetCount)
        );
        // Witchcraft ahead 🧹.
        Echo echo = new Echo(bytecodeWithArgs);
        assembly ('memory-safe') {
            let s := delegatecall(
                gas(),
                echo,
                add(bytecodeWithArgs, 0x20),
                mload(bytecodeWithArgs),
                0x0,
                0
            )
            if iszero(s) { revert(0, 0) }
            returndatacopy(0x00, 0x00, returndatasize())
            return(0x00, returndatasize())
        }
    }

    // Just to shush the compiler.
    function createBundle(uint8 /* builderIdx */)
        external virtual returns (PlayerBundle memory bundle)
    {}

    // Just to shush the compiler.
    function buildBlock(PlayerBundle[] calldata bundles)
        external virtual returns (uint256 goldBid)
    {}

    function _getBytecode() private pure returns (bytes memory) {
        // Paste bytecode below.
        return
            hex"6101203461012357601f610d7438819003918201601f19168301916001600160401b0383118484101761012757808492608094604052833981010312610123578051906001600160a01b03821682036101235761005e6020820161013b565b610076606061006f6040850161013b565b930161013b565b9260805260a05260c0528060e05260ff5f1991160160ff811161010f5761010052604051610c2a908161014a823960805181818161013a01528181610584015281816107ee015281816109e301528181610a370152610b95015260a05181818160a30152818161054e015281816108190152610a85015260c05181505060e05181818161015f01526104c20152610100518161083b0152f35b634e487b7160e01b5f52601160045260245ffd5b5f80fd5b634e487b7160e01b5f52604160045260245ffd5b519060ff821682036101235756fe6080806040526004361015610012575f80fd5b5f3560e01c9081631ad9b0801461048f5750637824568214610032575f80fd5b346102ea5760203660031901126102ea5760043567ffffffffffffffff81116102ea57366023820112156102ea57806004013561006e81610787565b9161007c6040519384610765565b8183526024602084019260051b820101903682116102ea5760248101925b8284106103a4577f000000000000000000000000000000000000000000000000000000000000000060ff811690865f5b81519060ff8116918210156101245781818660ff941461011d575f6100f26100f893876107c4565b51610951565b1660ff8114610109576001016100ca565b634e487b7160e01b5f52601160045260245ffd5b50506100f8565b505050906101306107ec565b6001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000169260ff7f0000000000000000000000000000000000000000000000000000000000000000811692919082165f5b60ff811690858210156103335782821461032757604051636e3ea49b60e11b815260ff8581166004830152821660248201526020816044818c5afa9081156102ac575f916102f6575b50610219602060646101e1846107ae565b604051635da521eb60e11b815260ff80881660048301528b16602482015291900460448201529182908c9082905f9082906064820190565b03925af180156102ac576102c4575b5082156102b75761023a6064916107ae565b0460405192635da521eb60e11b845260048401525f602484015260448301526020826064815f8c5af19081156102ac5760ff9260019261027e575b505b0116610187565b61029e9060203d81116102a5575b6102968183610765565b81019061079f565b5089610275565b503d61028c565b6040513d5f823e3d90fd5b5060ff9150600190610277565b6020813d82116102ee575b816102dc60209383610765565b810103126102ea5751610228565b5f80fd5b3d91506102cf565b90506020813d821161031f575b8161031060209383610765565b810103126102ea5751896101d0565b3d9150610303565b60ff9150600190610277565b604051636e3ea49b60e11b8152600481018890525f60248201526020816044818c5afa80156102ac575f90610371575b60209060011c604051908152f35b506020813d60201161039c575b8161038b60209383610765565b810103126102ea5760209051610363565b3d915061037e565b833567ffffffffffffffff81116102ea578201602060231982360301126102ea57604051906103d282610719565b602481013567ffffffffffffffff81116102ea57602491010136601f820112156102ea57803561040181610787565b9161040f6040519384610765565b818352602060608185019302820101903682116102ea57602001915b81831061044557505050815281526020938401930161009a565b6060833603126102ea57602060609160405161046081610749565b610469866106b2565b81526104768387016106b2565b838201526040860135604082015281520192019161042b565b346102ea5760203660031901126102ea576104a86106a2565b506104b281610719565b606081526104be6107ec565b60ff7f000000000000000000000000000000000000000000000000000000000000000016916104ec83610787565b6104f96040519182610765565b838152601f1961050885610787565b015f5b818110610673575050815260ff5f9216915b60ff8116848110156106595783810361053d575b5060010160ff1661051d565b604051636e3ea49b60e11b815260ff7f00000000000000000000000000000000000000000000000000000000000000008116600483015283166024820152916020836044817f00000000000000000000000000000000000000000000000000000000000000006001600160a01b03165afa9283156102ac575f93610626575b50816106185760638302928084046063149015171561010957610610600192606460ff95045b604051906105ef82610749565b828252886020830152604082015286519061060a83836107c4565b526107c4565b509150610531565b61061060019260ff946105e2565b9092506020813d8211610651575b8161064160209383610765565b810103126102ea575191866105bc565b3d9150610634565b6040516020808252819061066f908201866106c0565b0390f35b60209060409695965161068581610749565b5f81525f838201525f60408201528282860101520194939461050b565b6004359060ff821682036102ea57565b359060ff821682036102ea57565b602060408184019251938281528451809452019201905f5b8181106106e55750505090565b909192602060606001926040875160ff815116835260ff8582015116858401520151604082015201940191019190916106d8565b6020810190811067ffffffffffffffff82111761073557604052565b634e487b7160e01b5f52604160045260245ffd5b6060810190811067ffffffffffffffff82111761073557604052565b90601f8019910116810190811067ffffffffffffffff82111761073557604052565b67ffffffffffffffff81116107355760051b60200190565b908160209103126102ea575190565b9060328202918083046032149015171561010957565b80518210156107d85760209160051b010190565b634e487b7160e01b5f52603260045260245ffd5b7f00000000000000000000000000000000000000000000000000000000000000006001600160a01b0316907f00000000000000000000000000000000000000000000000000000000000000005f7f000000000000000000000000000000000000000000000000000000000000000060ff1681805b60ff8116838110156109055760010160ff811161010957604051636e3ea49b60e11b815260ff878116600483015282166024820152906020826044818c5afa9182156102ac575f926108d2575b50818611156108c4575b505060010160ff16610860565b9094509150600160ff6108b7565b9091506020813d82116108fd575b816108ed60209383610765565b810103126102ea5751905f6108ad565b3d91506108e0565b50509450505050565b908160209103126102ea575180151581036102ea5790565b60409060ff610940949316815281602082015201906106c0565b90565b906001820180921161010957565b9091815151831015610b6d576109688383516107c4565b51915f936040840151610a30575b9061098461098a9392610943565b90610951565b81610993575050565b806109ae6109a660208094015160ff1690565b915160ff1690565b604051635da521eb60e11b815260ff9283166004820152911660248201526044810192909252816064815f6001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000165af18015610a2b57610a13575b50565b610a109060203d6020116102a5576102968183610765565b6102ac565b83519094507f00000000000000000000000000000000000000000000000000000000000000006001600160a01b031692919060ff1692610a74602086015160ff1690565b604051636e3ea49b60e11b815260ff7f0000000000000000000000000000000000000000000000000000000000000000811660048301528616602482015291602083604481845afa918215610a2b57610b07966020945f94610b4c575b505f9060405198899586948593635da521eb60e11b85526004850160ff6040929594938160608401971683521660208201520152565b03925af1928315610a2b5761098a93610984915f91610b2d575b50959192935050610976565b610b46915060203d6020116102a5576102968183610765565b5f610b21565b5f919450610b6690863d88116102a5576102968183610765565b9390610ad1565b60405163238d5da760e01b8152925060209183918291610b909160048401610926565b03815f7f00000000000000000000000000000000000000000000000000000000000000006001600160a01b03165af18015610a2b57610bcc5750565b610a109060203d602011610bed575b610be58183610765565b81019061090e565b503d610bdb56fea2646970667358221220a78b1c720aa0bc119ab10c08513cbc638c88dcc4c639eae7272ce4e38f675ce264736f6c634300081a0033";
    }
}

contract Echo {
    constructor(bytes memory data) {
        assembly ("memory-safe") {
            return(add(data, 0x20), mload(data))
        }
    }
}