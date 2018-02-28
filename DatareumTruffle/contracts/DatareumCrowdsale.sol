import "./Oraclize.sol";
import "./Ownable.sol";
import "./SafeMath.sol";

//Abstract Token contract
contract DatareumToken{
  function setCrowdsaleContract (address) public;
  function sendCrowdsaleTokens(address, uint256)  public ;
  function setIcoFinishedTrue () public;

}

//Crowdsale contract
contract DatareumCrowdsale is Ownable, usingOraclize{

  using SafeMath for uint;

  uint decimals = 18;

  // Token contract address
  DatareumToken public token;

  uint public startingExchangePrice = 1165134514779731;
  uint public tokenPrice; //0.03USD

  // Constructor
  function DatareumCrowdsale(address _tokenAddress) public payable{
    token = DatareumToken(_tokenAddress);
    owner = msg.sender;

    token.setCrowdsaleContract(this);
    
    oraclize_setNetwork(networkID_auto);
    oraclize = OraclizeI(OAR.getAddress());
    
    tokenPrice = startingExchangePrice*3/100;

    oraclizeBalance = msg.value;

    startOraclize(findElevenPmUtc());
  }


  function getPhase(uint _time) public pure returns(uint8) {
    if (PRE_ICO_START <= _time && _time < PRE_ICO_FINISH){
      return 1;
    }
    if (ICO_START <= _time && _time < ICO_FINISH){
      return 2;
    }
    return 0;
  }

  function getPreIcoBonus() public pure returns(uint) {
    return 20;  
  }

  function getIcoBonus () public pure returns(uint) {
    return 0;
  }
  

  //PRE ICO CONSTANTS
  uint public constant PRE_ICO_MIN_DEPOSIT = 0 ether; //5 ether
  uint public constant PRE_ICO_MAX_DEPOSIT = 100 ether;

  uint public constant PRE_ICO_MIN_CAP = 0;
  // uint public constant PRE_ICO_MAX_CAP = 2000000 ether;
  uint public PRE_ICO_MAX_CAP = startingExchangePrice.mul((uint)(2000000)); //2 000 000 USD

  uint public constant PRE_ICO_START = 0; //1527768000
  uint public constant PRE_ICO_FINISH = 1528761540;
  //END PRE ICO CONSTANTS

  //ICO CONSTANTS
  uint public constant ICO_MIN_DEPOSIT = 0.1 ether;
  uint public constant ICO_MAX_DEPOSIT = 100 ether;

  uint public ICO_MIN_CAP = startingExchangePrice.mul((uint)(5000000)); // 500 000 USD
  // uint public constant ICO_MAX_CAP = 2000000 ether;

  uint public constant ICO_START = 1530316800;
  uint public constant ICO_FINISH = 1533081540;
  //END ICO CONSTANTS

  uint public ethCollected = 0;

  mapping (address => uint) contributorEthCollected;
  

  mapping (address => bool) public whiteList;
  
  function addToWhiteList(address[] _addresses) public onlyOwner {
    for (uint i = 0; i < _addresses.length; i++){
      whiteList[_addresses[i]] = true;
    }
  }

  function removeFromWhiteList (address[] _addresses) public onlyOwner {
    for (uint i = 0; i < _addresses.length; i++){
      whiteList[_addresses[i]] = false;
    }
  }

  event OnSuccessBuy (address indexed _address, uint indexed _EthValue, uint indexed _percent, uint _tokenValue);

  function () public payable {
    require (whiteList[msg.sender]);
    require (buy(msg.sender, msg.value, now));

  }

  function buy (address _address, uint _value, uint _time) internal returns(bool)  {
    uint8 currentPhase = getPhase(_time);
    require (currentPhase > 0);

    uint bonusPercent = 0;

    ethCollected = ethCollected.add(_value);

    uint tokensToSend = (_value.mul((uint)(10).pow(decimals))/tokenPrice);

    if (currentPhase == 1){
      require (_value >= PRE_ICO_MIN_DEPOSIT && _value <= PRE_ICO_MAX_DEPOSIT);

      bonusPercent = getPreIcoBonus();

      tokensToSend = tokensToSend.add(tokensToSend.mul(bonusPercent)/100);

      require (ethCollected.add(_value) <= PRE_ICO_MAX_CAP);

      if (ethCollected > PRE_ICO_MIN_CAP){
        owner.transfer(this.balance.sub(oraclizeBalance));
      }

    }else if(currentPhase == 2){
      require (_value >= ICO_MIN_DEPOSIT && _value < ICO_MAX_DEPOSIT);

      contributorEthCollected[_address] = contributorEthCollected[_address].add(_value);

      bonusPercent = getIcoBonus();

      tokensToSend = tokensToSend.add(tokensToSend.mul(bonusPercent)/100);

      if (ethCollected > ICO_MIN_CAP){
        owner.transfer(this.balance.sub(oraclizeBalance));
      }
    }

    token.sendCrowdsaleTokens(_address,tokensToSend);

    OnSuccessBuy(_address, _value, bonusPercent, tokensToSend);

    return true;
  }
  
  uint public priceUpdateAt = 0;
  
  event newPriceTicker(string price);
  
  function __callback(bytes32, string result, bytes) public {
    require(msg.sender == oraclize_cbAddress());

    uint256 price = 10 ** 23 / parseInt(result, 5);

    require(price > 0);
    // currentExchangePrice = price;
    tokenPrice = price*3/100;
    
    PRE_ICO_MAX_CAP = price.mul((uint)(2000000)); //2 000 000 USD
    ICO_MIN_CAP = price.mul((uint)(500000)); //500 000 USD


    priceUpdateAt = block.timestamp;
        
    newPriceTicker(result);
    
    if(updateFlag){
      update();
    }
  }
  
  bool public updateFlag;
  
  function update() internal {
    oraclize_query(60,"URL", "json(https://api.kraken.com/0/public/Ticker?pair=ETHUSD).result.XETHZUSD.c.0");
    //86400 - 1 day
  
    oraclizeBalance = oraclizeBalance.sub(oraclize_getPrice("URL")); //request to oraclize
  }
  

  uint public oraclizeBalance = 0;

  function addEtherForOraclize () public payable {
    oraclizeBalance = oraclizeBalance.add(msg.value);
  }

  function requestOraclizeBalance () public onlyOwner {
    updateFlag = false;
    if (this.balance >= oraclizeBalance){
      owner.transfer(oraclizeBalance);
    }else{
      owner.transfer(this.balance);
    }
    oraclizeBalance = 0;
  }
  
  function stopOraclize () public onlyOwner {
    updateFlag = false;
  }

  function findElevenPmUtc () public view returns (uint) {

    uint eleven = 1514847600; // Put the erliest 11pm timestamp

    for (uint i = 0; i < 30; i++){
      eleven = eleven + 1 days;
      if(eleven > now){
        return eleven.sub(now);
      }
    }
    return 0;
  }

  function startOraclize (uint _time) public onlyOwner {
    require (_time != 0);
    updateFlag = true;
    oraclize_query(_time,"URL", "json(https://api.kraken.com/0/public/Ticker?pair=ETHUSD).result.XETHZUSD.c.0");
  }

  function refund () public {
    require (now > ICO_FINISH && ethCollected < ICO_MIN_CAP);
    require (contributorEthCollected[msg.sender] > 0);

    msg.sender.transfer(contributorEthCollected[msg.sender]);
    contributorEthCollected[msg.sender] = 0;
  }
  
}