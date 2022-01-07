pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TokenVesting {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    IERC20 public token;//要分发的token
    mapping(address => bool) owners;//管理员
    uint256 scheduleId;//序号
    uint totalAmount;//总共要分发的token
    uint256 public constant VESTING_PERIOD = 2592000;// 1 month in seconds
    uint256 startTime;//开始时间
    bool public hasStart;//是否已经开始

    modifier onlyOwner {
        require(owners[msg.sender], "_onlyOwner: sender is not an owner.");
        _;
    }
    function hashCompareInternal(string memory _str1, string memory _str2) public pure returns(bool) {
        return (keccak256(abi.encodePacked(_str1)) == keccak256(abi.encodePacked(_str2)));
    }
    struct Schedule {
        string vestType;
        uint256 amountPeriod;
    }
    struct Account{
        uint256 withdraw;
        uint256 released;
        uint256 amount;
        uint256 num;
        mapping (uint256=>Schedule) scheduleList;
    }

    mapping (address=>Account) accountList;


    event COM_IEO(string vestType,uint256 amount);
    event COM_IDO(string vestType,uint256 amount);
    event COM_IAO(string vestType,uint256 amount);
    event COM_IBO(string vestType,uint256 amount);
    constructor(address _token){
        token=IERC20(_token);
        owners[msg.sender]=true;
    }

    function addOwner(address _owner) public onlyOwner{
        owners[_owner]=true;
    }
    function removeOwner(address _owner) public onlyOwner{
        owners[_owner]=false;
    }
    function setStart(uint256 _startTime) public onlyOwner{
        require(hasStart==false,"Has start");
        startTime=_startTime;
        hasStart=true;
    }
    //增加数据
    /**
    * vestType:类型
    * holder:所有者
    * startPeriod:开始时间
    * amountPeriod:数量
    */
    function addSchedule(string memory vestType,address user, uint256 amountPeriod) external onlyOwner(){
        require(amountPeriod>0,"Assigned quantity cannot be 0");
        Schedule memory schedule;
        schedule.vestType=vestType;
        schedule.amountPeriod = amountPeriod;
        //如果记录不存在，则新增记录
        if(accountList[user].amount==0){
            Account storage account=accountList[user];
            account.amount=amountPeriod;
            account.released=0;
            account.withdraw=0;
            account.scheduleList[account.num]=schedule;
            account.num=account.num.add(1);
        }else{
            //如果记录存在，则更新记录
            Account storage account=accountList[user];
            account.amount=account.amount.add(amountPeriod);
            account.scheduleList[account.num]=schedule;
            account.num=account.num.add(1);
        }
        totalAmount=totalAmount.add(amountPeriod);
    }
    //查询用户的可提现数量
    function balanceOf(address user) public view returns(uint256 releasedNum){
        require(user==msg.sender,"You can only view your own account");
        if(hasStart==false || block.timestamp<startTime){
            return 0;
        }
        Account storage account=accountList[user];
        for(uint i=0;i<account.num;i++){
            Schedule memory schedule=account.scheduleList[i];
            if(hashCompareInternal(schedule.vestType,"IEO")){
                releasedNum=releasedNum.add(schedule.amountPeriod);
            }
            else if(hashCompareInternal(schedule.vestType,"IDO")){
                if((block.timestamp-startTime)>VESTING_PERIOD){
                    releasedNum=releasedNum.add(schedule.amountPeriod);

                }else{
                    uint256 halfAmount=schedule.amountPeriod.mul(50).div(100);
                    releasedNum=releasedNum.add(halfAmount);

                }
            }else if(hashCompareInternal(schedule.vestType,"IAO")){
                if((block.timestamp-startTime)<(VESTING_PERIOD.mul(3))){
                    uint256 firstAmount=schedule.amountPeriod.mul(5).div(100);
                    releasedNum=releasedNum.add(firstAmount);
                }else if ((block.timestamp-startTime)<(VESTING_PERIOD.mul(24))){
                    uint256 secondAmount=(block.timestamp-startTime-VESTING_PERIOD.mul(2)).div(VESTING_PERIOD).mul(schedule.amountPeriod.mul(95).div(100).div(23));
                    uint256 firstAmount=schedule.amountPeriod.mul(5).div(100);
                    releasedNum=releasedNum.add(firstAmount);
                    releasedNum=releasedNum.add(secondAmount).add(firstAmount);
                } else{
                    releasedNum=releasedNum.add(schedule.amountPeriod);
                }
            }else if(hashCompareInternal(schedule.vestType,"IBO")){
                if((block.timestamp-startTime)<(VESTING_PERIOD.mul(7))){
                    releasedNum=releasedNum;
                }else if ((block.timestamp-startTime)<(VESTING_PERIOD.mul(24))){
                    uint256 secondAmount=(block.timestamp-startTime-VESTING_PERIOD.mul(7)).div(VESTING_PERIOD.mul(3)).mul(schedule.amountPeriod.div(6));
                    releasedNum=releasedNum.add(secondAmount);
                } else{
                    releasedNum=releasedNum.add(schedule.amountPeriod);
                }
            }
        }
        return(releasedNum-account.withdraw);
    }
    function withdraw() public{
        // 获取用户的可提现数量
        uint256 releasedNum=balanceOf(msg.sender);
        Account storage account=accountList[msg.sender];
        require(releasedNum<=account.amount);
        require(account.withdraw.add(releasedNum)<=account.amount);
        account.withdraw=account.withdraw.add(releasedNum);
        token.safeTransfer(msg.sender, releasedNum);
    }
    function getAccountInfo() public view returns(uint256 _amount,uint256 _released,uint256 _withdraw,uint256 _num){
        Account storage account=accountList[msg.sender];
        return(account.amount,account.released,account.withdraw,account.num);
    }
    function getScheduleInfo(uint256 id) public view returns(string memory,uint256){
        Account storage account=accountList[msg.sender];
        Schedule memory achedule=account.scheduleList[id];
        return(achedule.vestType,achedule.amountPeriod);
    }
    function getBlockTime() public view returns(uint256){
        return block.timestamp;
    }
}
