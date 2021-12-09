pragma solidity 0.5.17;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v2.5.0/contracts/token/ERC20/ERC20.sol";


contract ERC20Token is ERC20 {
    string private _name;
    string private _symbol;
    uint8  private _decimals;
    bool   private _initialized;

    function initialize(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 totalSupply,
        address owner
    ) public {
        require(!_initialized, "ERR_TOKEN_HAS_INITIALIZED");
        _initialized = true;

        _name = name;
        _symbol = symbol;
        _decimals = decimals;

        _mint(owner, totalSupply);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }
}
