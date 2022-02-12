pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;
/*
BSN
*/
abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}
library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}


interface IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address _owner) external view returns (uint256 balance);

    function transfer(address _to, uint256 _value)
    external
    returns (bool success);

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool success);

    function approve(address _spender, uint256 _value)
    external
    returns (bool success);

    function allowance(address _owner, address _spender)
    external
    view
    returns (uint256 remaining);
}
contract GaiaStaking is ReentrancyGuard{
    using SafeMath for uint256;

    uint256 public constant day = 86400;//一天的秒数,测试环境设置为1s，正式环境为 86400
    uint256 private constant stakingType1=90;
    uint256 private constant stakingType2=180;
    uint256 private constant stakingType3=360;
    uint256 private constant ONE = 10**18;
    bool public isStartWithdraw=false;//是否开启提现

    struct Stream{
        uint256 streamId;
        address sender;//存币人
        uint256 stakingType;//存币类型
        uint256 stakingAmount;//数量
        uint256 stakingTime;//存币时间
        uint256 endTime;//预期结束时间
        uint256 withdrawable;//可提现数量
        bool finish;//是否已经取出
    }
    struct UserStream{
        uint256 amount;//存入的笔数
        uint256 balance;//存入的总额
        Stream[] streams;//用户存入的具体信息
    }
    IERC20 stakingToken;//允许存入的币种
    mapping(address=>UserStream) private userList;//用户列表

    address owner;
    event Staking(uint256 indexed streamId,address indexed sender,uint256 indexed stakingAmount,uint256 stakingTime,uint256 endTime);
    event Withdraw(uint256 indexed streamId,address indexed sender,uint256 indexed withdrawAmount,uint256 withdrawTime);
    event ChangeWithdrawState(address indexed owner,bool indexed state);
    event ChangeOwner(address indexed owner,address indexed user);

    modifier streamExists(uint256 streamId) {
        require(userList[msg.sender].streams[streamId].sender!=address(0), "stream does not exist");
        _;
    }
    modifier onlyOwner {
        require(msg.sender == owner, "not governance");
        _;
    }
    constructor(address token) public{
        stakingToken=IERC20(token);
        owner=msg.sender;
    }
    /**
    * 自己存币
    * stakingType=90 表示90天，20%收益
    * stakingType=180 表示180天，40%收益
    * stakingType=360 表示360天，60%收益
    */
    function staking(uint256 stakingType,uint256 stakingAmount) public nonReentrant{
        stakingBase(msg.sender,stakingType, stakingAmount, block.timestamp);
    }
    // 给别人存
    function stakingTo(address toUser,uint256 stakingType,uint256 stakingAmount,uint256 stakingTime) public onlyOwner nonReentrant{
        stakingBase(toUser,stakingType, stakingAmount, stakingTime);
    }
    function stakingBase(address _toUser,uint256 _stakingType,uint256 _stakingAmount,uint256 _stakingTime) internal{
        require(_stakingAmount>=10*ONE);
        require(_stakingType==stakingType1 || _stakingType==stakingType2 || _stakingType==stakingType3,"Wrong Staking type");
        stakingToken.transferFrom(msg.sender, address(this), _stakingAmount);
        uint256 _endTime;
        _endTime=_stakingTime.add(_stakingType*day);
        Stream memory stream=Stream({
        streamId:userList[_toUser].amount,
        sender: _toUser,
        stakingType:_stakingType,
        stakingAmount: _stakingAmount,
        stakingTime: _stakingTime,
        endTime:_endTime,
        finish:false,
        withdrawable:_stakingAmount
        });
        userList[_toUser].amount+=1;
        userList[_toUser].balance+=_stakingAmount;
        userList[_toUser].streams.push(stream);
        emit Staking(stream.streamId,msg.sender,_stakingAmount,_stakingTime,_endTime);
    }
    function computeAmount(uint256 stakingType,uint256 inAmount,uint256 stakingTime) internal view returns(uint256 outAmount){

        uint256 rate;
        if (stakingType==stakingType1){
            rate=20;
        }else if (stakingType==stakingType2){
            rate=40;
        }else if (stakingType==stakingType3){
            rate=60;
        }
        //当前时间
        uint256 time=block.timestamp;
        if((time-stakingTime)>(stakingType*day)){
            outAmount=inAmount+inAmount.mul(rate*stakingType).div(100*360);
        }else{
            outAmount=inAmount;
        }
    }
    //取币
    function withdraw(uint256 streamId) public streamExists(streamId) nonReentrant{
        // 只有开启提币后，才能提取
        require(isStartWithdraw==true);
        // 只有存入的人可以取币
        // require(stakingList[streamId].sender==msg.sender);
        Stream memory stream=userList[msg.sender].streams[streamId];
        require(stream.sender==msg.sender);
        // 不能已经结束
        require(stream.finish==false);

        uint256 outAmount=computeAmount(stream.stakingType,stream.stakingAmount,stream.stakingTime);
        //给用户转币
        stakingToken.transfer(stream.sender, outAmount);
        stream.finish=true;
        stream.withdrawable=0;
        require(userList[msg.sender].balance>=stream.stakingAmount);
        userList[msg.sender].balance-=stream.stakingAmount;
        userList[msg.sender].streams[streamId]=stream;
        emit Withdraw(streamId,msg.sender,outAmount,block.timestamp);
    }
    //获取流信息
    function getStream(uint256 streamId) external view streamExists(streamId) returns(address sender,uint256 stakingType,uint256 stakingAmount,uint256 stakingTime,uint256 endTime,bool finish,uint256 nowAmount){
        Stream memory stream=userList[msg.sender].streams[streamId];
        sender=stream.sender;
        stakingType=stream.stakingType;
        stakingAmount=stream.stakingAmount;
        stakingTime=stream.stakingTime;
        endTime=stream.endTime;
        finish=stream.finish;
	    if(stream.finish==true){
            nowAmount=0;
        }else{
            nowAmount=computeAmount(stream.stakingType,stream.stakingAmount,stream.stakingTime);
        }
    }
    // 获取用户存入总额
    function getBalance(address user) public view returns(uint256){
        return userList[user].balance;
    }
    //获取可提现数量
    function getWithdrawAmount(uint256 streamId) public streamExists(streamId) view returns(uint256 outAmount){
        Stream memory stream=userList[msg.sender].streams[streamId];
        // 如果已经结束
        if(stream.finish==true){
            return 0;
        }
        outAmount=computeAmount(stream.stakingType,stream.stakingAmount,stream.stakingTime);
        return outAmount;
    }
    function getUserStreamList(address user) public view returns(Stream[] memory){
        UserStream memory userStream=userList[user];
        for(uint256 i=0;i<userStream.amount;i++){
            Stream  memory stream=userStream.streams[i];
            // 如果已经结束
            if(stream.finish==true){
                stream.withdrawable=0;
            }else{
                stream.withdrawable=computeAmount(stream.stakingType,stream.stakingAmount,stream.stakingTime);
            }
            userStream.streams[i]=stream;
        }
        return userStream.streams;
    }

    function changeOwner(address _owner) public onlyOwner{
        require(_owner!=address(0));
        owner=_owner;
        emit ChangeOwner(msg.sender,_owner);
    }
    function getOwner() public view returns(address){
        return owner;
    }
    function withdrawOwner() public onlyOwner{
        uint256 balance=stakingToken.balanceOf(address(this));
        stakingToken.transfer(owner, balance);
    }

    function startWithdraw() public onlyOwner{
        isStartWithdraw=true;
        emit ChangeWithdrawState(msg.sender,true);
    }
    function stopWithdraw() public onlyOwner{
        isStartWithdraw=false;
        emit ChangeWithdrawState(msg.sender,false);
    }
}
