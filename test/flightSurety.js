
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

//   it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
//     // ARRANGE
//     let newAirline = accounts[2];

//     // ACT
//     try {
//         await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
//     }
//     catch(e) {

//     }
//     let result = await config.flightSuretyData.isAirline.call(newAirline); 

//     // ASSERT
//     assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

//   });



it('(airline) register an Airline when contract is deployed', async () => {
    let result = await config.flightSuretyData.isAirline.call(config.firstAirline);
    assert.equal(result, true, "First Airline was not created");
});

it('(airline) can not register second an Airline from NON airline address', async () => {
    let newAirline = accounts[3];

    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: accounts[4]});
    } catch (e) {
    }
    let result = await config.flightSuretyData.isAirline.call(newAirline);

    assert.equal(result, false, "Can create second airline from non airline address");

});
it('(airline) can register second an Airline from airline address', async () => {
    let newAirline = accounts[4];

    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    } catch (e) {
    }
    let result = await config.flightSuretyData.isAirline.call(newAirline);
    assert.equal(result, true, "Can not create second airline from airline address");

});
it('(airline) can register 5th an Airline with needApprove == true', async () => {
    
    try {
        await config.flightSuretyApp.registerAirline(accounts[5], {from: config.firstAirline});
        await config.flightSuretyApp.registerAirline(accounts[6], {from: config.firstAirline});
        await config.flightSuretyApp.registerAirline(accounts[7], {from: config.firstAirline}); /* 5th airline */
    } catch (e) {
    }
    let result = await config.flightSuretyData.getAirline.call(accounts[7]);
    // let result6 = await config.flightSuretyData.getAirline.call(accounts[6]);
    // console.log("airline4 " + result6.needApprove);
    // console.log("airline5 " + result.needApprove);
    // assert.equal(result6.needApprove, false, "4th airline ");
    assert.equal(result.needApprove, true, "Can create airlines without multi approval");
});

it('(airline) vote airlines', async () => {
    const airlineToVote = accounts[7];
    try {
        await config.flightSuretyApp.voteAirline(airlineToVote, {from: config.firstAirline});
    } catch (e) { console.log(e); }
    let result1 = await config.flightSuretyData.getAirline.call(airlineToVote);
    assert.equal(result1.needApprove, true, "Need more votes to be approved");
    // console.log("Vote 1 " + result1.needApprove);
    try {
        await config.flightSuretyApp.voteAirline(airlineToVote, {from: accounts[5]});
    } catch (e) { console.log(e); }
    let result2 = await config.flightSuretyData.getAirline.call(airlineToVote);
    assert.equal(result2.needApprove, true, "Must be approved");
    // console.log("Vote 2 " + result2.needApprove);

    // for the fifth registered airline the min votes required is 3 and when we vote the Airline the third time then the needAPprive is set to false. therefore a successful test.
    try {
        await config.flightSuretyApp.voteAirline(airlineToVote, {from: accounts[6]});
    } catch (e) { console.log(e); }
    let result3 = await config.flightSuretyData.getAirline.call(airlineToVote);
    assert.equal(result3.needApprove, false, "Must be approved");
    // console.log("Vote 3 " + result3.needApprove);
});


it('(airline) fund airlines', async () => {
    try {
        await config.flightSuretyApp.fundAirline({from: accounts[7], value: web3.utils.toWei('10', "ether")});
    } catch (e) { console.log(e.message)}
    const resultSuccess = await config.flightSuretyData.getAirline.call(accounts[7]);
    assert.equal(resultSuccess.isFunded, true, "Should funded approved airline");
});
 
// it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
//         // ARRANGE
//         let newAirline = accounts[9];
    
//         // ACT
//         try {
//             await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
//         } catch (e) {
    
//         }
//         let result = await config.flightSuretyData.isAirline.call(newAirline);
    
//         // ASSERT
//         assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");
    
//     });

it('airline is only operational when it has submitted funding of 10 ether', async () => {

    // ARRANGE
    let admin2 = accounts[6];
    let admin3 = accounts[7];
    let fundPrice = web3.utils.toWei("10", "ether");

    try{
        await config.flightSuretyData.fund(admin2);
        await config.flightSuretyData.fund(admin3);
        // await config.flightSuretyApp.fundAirline( {from: admin2, value: fundPrice});
        // await config.flightSuretyApp.fundAirline( {from: admin3, value: fundPrice});

    }catch(e){
        console.log('Funding has failed');
    }

    let result = await config.flightSuretyData.getAirlineOperatingStatus.call(admin3);

    // ASSERT
    assert.equal(result, true, "Status is not true")

  });





  //Passenger

  it('Passenger can buy flight inssurance for at most 1 ether', async () => {

    // ARRANGE
    let passenger6 = accounts[8];
    let airline = accounts[6];
    let rawAmount = 1;
    let InsuredPrice = web3.utils.toWei(rawAmount.toString(), "ether");

    try{
        await config.flightSuretyData.buy(airline, {from: passenger6, value: InsuredPrice});

    }catch(e){

    }

    let result = await config.flightSuretyData.getInsuredPassenger_amount.call(airline);
    // console.log("value "+ result[1])
    // ASSERT
    assert.equal(result[0], passenger6, "Status is not true")

  });


  it('Insured passenger can be credited if flight is delayed', async () => {

    // ARRANGE
    let passenger = accounts[8];
    let airline = accounts[6];
    let credit_status = true;
    let balance = 1.5;
    let credit_before = 0
    let credit_after = 0
    let STATUS_CODE_LATE_AIRLINE = 20;
    let flight = 'FLGT002';
    let timestamp = Math.floor(Date.now() / 1000);

   
    try{
        // Check credit before passenger was credited
        credit_before = await config.flightSuretyData.getPassengerBalance.call(passenger, {from: passenger});
        credit_before = web3.utils.fromWei(credit_before, "ether")
        // console.log("Credit Before "+credit_before);

        // Credit the passenger
        await config.flightSuretyApp.processFlightStatus(airline, flight, timestamp, STATUS_CODE_LATE_AIRLINE);
        

        // Get credit after passenger has been credited
        credit_after = await config.flightSuretyData.getPassengerBalance.call(passenger, {from: passenger});
        credit_after = web3.utils.fromWei(credit_after, "ether");
        // console.log("Credit after "+credit_after);


    }catch(e){
        // console.log("Error" + e);
        credit_status = false;
    }


    // ASSERT
    assert.equal(balance, credit_after, "Credited balance not as expected")
    assert.equal(credit_status, true, "Passenger was not credited");

  });

    it('Credited passenger can withdraw ether(transfer from airline to passenger)', async () => {

    // ARRANGE
    let passenger = accounts[8];
    let withdraw = true;
    let balance_before = 0;
    let balance_after = 0;
    let eth_balance_before = 0;
    let eth_balance_after = 0;
    let credit = 1.5;

    try{


        balance_before = await config.flightSuretyData.getPassengerBalance.call(passenger, {from:passenger})
        balance_before = web3.utils.fromWei(balance_before, "ether");

        eth_balance_before = await web3.eth.getBalance(passenger)
        eth_balance_before = web3.utils.fromWei(eth_balance_before, "ether");
        console.log("ETH balance before: ",eth_balance_before)

        await config.flightSuretyData.pay(passenger, {from:passenger});

        // Check if credit has been redrawn
        balance_after = await config.flightSuretyData.getPassengerBalance.call(passenger, {from:passenger})
        balance_after = web3.utils.fromWei(balance_after, "ether");

        eth_balance_after = await web3.eth.getBalance(passenger)
        eth_balance_after = web3.utils.fromWei(eth_balance_after, "ether");
        console.log("ETH balance after: ",eth_balance_after)

        console.log("The difference is ", eth_balance_after - eth_balance_before);

    }catch(e){
        // console.log("Error" + e);
        withdraw = false;
    }

    // ASSERT
    assert.equal(withdraw, true, "Passenger could not withdraw");
    assert.equal(balance_before,credit, "Redrawn credit doesn't match")
    assert.equal(balance_after, 0, "Credit was't redrawn");
    assert.ok((eth_balance_after - eth_balance_before) > 0, "Credited was not transfered to wallet");

  });

});
