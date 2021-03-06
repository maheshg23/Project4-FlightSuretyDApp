pragma solidity >0.5.0;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./FlightSuretyData.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    FlightSuretyData dataContract;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    bool private operational = true;

    uint public MAX_AUTO_REGISTERED_AIRLINES = 4;

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract

    struct Flight {
        address airline;
        uint256 timestamp;
        uint8 statusCode;
        address passenger;
        uint256 value;
    }
    mapping(bytes32 => Flight) private flights;


    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational()
    {
         // Modify to call data contract's status
        require(true, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier canAirlineCreateOrUpdate() {
        bool canCreate = (dataContract.getAirlinesCount() == 0) || (dataContract.isAirline(msg.sender) == true);
        require(canCreate == true, "You can not create or update airline");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor
                                (
                                    address payable dataContractAddress,
                                    address firstAirlineAddress
                                )
                                public
    {
        contractOwner = msg.sender;
        dataContract = FlightSuretyData(dataContractAddress);
        registerAirline(firstAirlineAddress);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational()
                            public
                            view
                            returns(bool)
    {

        return operational;  // Modify to call data contract's status
    }

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    event ToVoteAirline(address airline);
    event AirlineWasVoted(address airline, bool needApproved);
    event AirlineWasFunded(address airline);
    event InsurancePayout(address airline, string flight, uint256 timestamp, uint256 insurancePayoutValue, uint256 passengerBalance);
    event UpdatedPassengerBalance(uint256 balance);


    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/


   /**
    * @dev Add an airline to the registration queue
    *
    */
    function registerAirline
                            (address airlineAddress
                            )
                            public
                            requireIsOperational()
                            canAirlineCreateOrUpdate()
                            // returns(bool success, uint256 votes)
    {
        bool needAprrove = dataContract.getAirlinesCount() >= MAX_AUTO_REGISTERED_AIRLINES;

        dataContract.registerAirline(airlineAddress, needAprrove);
    }


    // function voteAirline(address airlineAddress) public requireIsOperational() canAirlineCreateOrUpdate() {
    //     bool needApproved = dataContract.voteAirline(airlineAddress, msg.sender);
    //     emit AirlineWasVoted(airlineAddress, needApproved);
    // }


    /**
     * @dev Add vote to airline, return needApprove flag
     *      Can only be called from FlightSuretyApp contract
     *
     */
    function voteAirline(address airlineAddress)
                        external
                        // checkAirlineExists(airlineAddress)
                        canAirlineCreateOrUpdate()
                        requireIsOperational()
    {
        require(dataContract.getAirlineIsVoted(airlineAddress,msg.sender) == false, "Airline already voted by this account");
        //require(airlines[airlineAddress].votes.voters[voterAddress] == false, "Airline already voted by this account");
        // airlines[airlineAddress].votes.votersCount = getAirline(airlineAddress).votes.votersCount.add(1);
        // airlines[airlineAddress].votes.voters[msg.sender] = true;

        // airlines[airlineAddress].needApprove = airlines[airlineAddress].votes.votersCount < airlines[airlineAddress].minVotes;
        // bool needApproved = airlines[airlineAddress].needApprove;

        uint votersCount = dataContract.getAirlineVotersCount(airlineAddress).add(1);
        bool isVote = true;
        uint minVotes = dataContract.getAirlineMinVotes(airlineAddress);
        bool needApproved = dataContract.getAirlineVotersCount(airlineAddress) < minVotes;

        dataContract.setAirlineInfo(airlineAddress, votersCount, isVote, needApproved);
        emit AirlineWasVoted(airlineAddress, needApproved);
    }

    /**
     * @dev Fund flight for insuring.
     *
     */
    function fundAirline() public payable requireIsOperational() canAirlineCreateOrUpdate(){
        require(msg.value >= 10 ether, 'No enough funds');
        dataContract.fund.value(msg.value)(msg.sender);
        emit AirlineWasFunded(msg.sender);
    }


   /**
    * @dev Register a future flight for insuring.
    *
    */
    function registerFlight
                                (
                                    address airline,
                                    string memory flight,
                                    uint256 timestamp
                                )
                                public
                                requireIsOperational
                                payable
    {
        require(msg.value <= 1 ether, 'Max pay value is 1 ether');
        require(msg.value > 0, 'Pay value is required');

        bytes32 key = getFlightKey(airline, flight, timestamp);

        flights[key] = Flight({
            airline: airline,
            timestamp: timestamp,
            statusCode: STATUS_CODE_UNKNOWN,
            passenger: msg.sender,
            value: msg.value
        });
        dataContract.buy.value(msg.value)(msg.sender);
    }

   /**
    * @dev Called after oracle has updated flight status
    *
    */
    function processFlightStatus
                                (
                                    address airline,
                                    string memory flight,
                                    uint256 timestamp,
                                    uint8 statusCode
                                )
                                public
                                requireIsOperational()
    {
        bytes32 key = getFlightKey(airline, flight, timestamp);
        flights[key].statusCode = statusCode;

        address passenger;
        uint256 amountPaid;
        (passenger,amountPaid) = dataContract.getInsuredPassenger_amount(airline);


        if (statusCode == STATUS_CODE_LATE_AIRLINE) {
            uint256 insurancePayoutValue = getInsurancePayoutValue(amountPaid);
            dataContract.creditInsurees(airline, insurancePayoutValue);
            // uint256 insurancePayoutValue = dataContract.getInsurancePayoutValue(airline);
            // uint256 passengerBalance = dataContract.getPassengerBalance(flights[key].passenger);
            // emit InsurancePayout(airline, flight, timestamp, insurancePayoutValue, passengerBalance);
        } else {
            dataContract.closeInsurance(airline);
        }
    }

    function getInsurancePayoutValue(uint256 amount) public pure requireIsOperational returns(uint256){
        // InsuranceInfo memory insurance = insurances[airline];
        uint256 insurancePayoutValue = amount.mul(3).div(2);
        return insurancePayoutValue;
    }


    function getPassengerBalance
                                (address passengerAddress)
                                public
                                view
                                requireIsOperational()
                                returns(uint256 balance)
    {
         return dataContract.getPassengerBalance(passengerAddress);
    }

    function withdrawPassengerFunds
                                ()
                                public
                                requireIsOperational()
    {
        uint256 passengerBalance = dataContract.getPassengerBalance(msg.sender);
        require(passengerBalance > 0, "Insufficient funds on passenger's balance");
        dataContract.pay(msg.sender);
        emit UpdatedPassengerBalance(dataContract.getPassengerBalance(msg.sender));
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        public
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    }

    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */
    function setOperatingStatus(bool mode) public requireContractOwner {
        operational = mode;
    }



// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3]memory )
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string calldata flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        internal
                        pure
                        returns(bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (
                                address account
                            )
                            internal
                            returns(uint8[3] memory)
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}

// contract FlightSuretyData {

//     function registerAirline(address airline) external;
//     function getInsuredPassenger_amount(address airline) external returns(address, uint256);
//     function creditInsurees (address airline,uint256 amount) external;
//     function getAirlinesCount() public view returns (uint256);
//     function isAirline(address airlineAddress) public view returns (bool);
//     function voteAirline(address airlineAddress, address voterAddress) external returns (bool);
//     function fund(address airlineAddress) external payable;
//     function buy(address airline) external payable;
//     function closeInsurance(address airline) external view;
//     function getPassengerBalance(address passengerAddress) public view returns(uint256);
//     function pay(address payable passengerAddress) external payable;

// }