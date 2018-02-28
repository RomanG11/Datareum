var Token = artifacts.require("./DatareumToken.sol");
var Crowdsale = artifacts.require("./DatareumCrowdsale.sol");

// var address = web3.eth.accounts[0];
module.exports = function(deployer) {
  deployer.deploy(Token).then(function(){
  	return deployer.deploy(Crowdsale,Token.address);
  });
}