//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;


// initial try to make an insurance contract
// initially check one value is bigger then anohter -> payout. 

contract insurance {
    // define policy. has ID, coverage and premium...
    struct Policy {
        uint policyId;
        uint coverage; // is paid out when policy is triggered
        uint premium;
        uint rainfallAmt; // in micrometer mm*1000. rainfall amt treshold, when above, then policy is triggered 
        uint region; 
        uint deductibleDays; // in seconds. number of days to be above rainfallAmt to start qualifying for reimbursement payments
        uint daysOverThreshold;
        address payable owner;
        uint startTime;
        uint endTime;
        bool hasEnded;
    }

    // owner of insurance contract
    address public insurer;

    // store Policy information in mapping with struct Policy
    mapping(uint => Policy) public policies;
    // array of all policy IDs -> for iteration through mapping of policies
    uint[] public allActivePolicies;

    // initialize poilicy ID.
    uint256 private nextId = 1;

    // Internal arrays to store affected policies and days over threshold
    uint[] internal affectedPolicies;
    uint[] internal daysOverTreshholdOfAffectedPolicies;

    // Events
    // who buys which policy?
    event NewPolicy(
        address indexed owner, 
        uint indexed policyId,
        uint region,
        uint coverage,
        uint premium,
        uint deductibleDays_inSeconds,
        uint duration_inSeconds,
        uint returnedAmount);

    event CoverageTriggered(
        uint policyId,
        address owner,
        uint timestamp,  // date as uint -> UNIX
        uint coverage,
        uint treshold_inSeconds, // in seconds
        uint dayOverTreshold,
        uint amountPaid, // in Wei
        bool success
    );

    event addWeatherData(
        uint indexed timestamp,
        uint dataValue,
        uint[] affectedPolicyIds,
        uint[] newCounts
    );

    // house keeping functions

    // withdraw left ofer Wei, when smart contract is not used anymore
    function withdraw() external returns (uint amount){
        require(msg.sender == insurer, "Not insurer");
        amount = address(this).balance;
        payable(insurer).transfer(amount);
    }

    // Function to get the balance of the contract
    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    function showAllPolicyIds() public view returns (uint[] memory){
        return allActivePolicies;
    }

    // store all polices by policy id:
    function newPolicy( 
        uint _coverage, 
        uint _rainfallAmt,
        uint _region,
        uint _startTime,
        uint _endTime
        ) public payable { // add payable for premium payment
                
        // check user input: Validty of policy
        // Policy must be initiated 2 weeks in advande to fullfill stochasticity of an (parametric) insurance contract
        //require(_startTime > block.timestamp + (14 * 24 * 60 * 60)); commented for testing

        // manage maximum duration of 91 day (source: Baloise):
        require(_endTime < (_startTime + (91 * 24 * 60 * 60)), "Maximum contract length is 91 days!");
        require(_endTime > _startTime, "endTime must be greater than startTime");
        require((_endTime - _startTime) > 60); // minimum duration must be 1 Minute (for testing)

        // manage regions input
        require(_region >= 1 && _region <= 5, "Invalid region");

        // manage policy ID
        uint _policyId = nextId++;
        // maybe build check to see if this policy id already exists?

        // how long is the trip in seconds:
        uint duration = (_endTime - _startTime);

        // get treshold for Region
        uint deductibleDays= (_region * duration)/ 10;

        // calculate premium (this is a simple implementation of a premium)
        // to act as an idea. Most likely an insurance company will not provide this in a public smart contract.
        // this is simply implemented for testing purposes 
        // example: premium = _coverage * (duration - deductibleDays) * 1/10 * _region * 11/10;
        uint premium = _coverage * (duration - deductibleDays) * _region * 11/100;
        // simple Idea: higher coverage increases premium
        // higher treshold decreases premium
        // longer trip increases premium
        // the larger the region, the higher the probablity for rain, multiplied with chance for rain of 10% (estimate)
        // 1.1 is a factor to cover the costs of insurance
        
        // check if paid premium is sufficient
        require(msg.value >= premium, 'payment lower than premium');
        // refund if more than premium is paid
        uint returnedAmount = 0;
        if (msg.value > premium) {
            returnedAmount = msg.value - premium;
            (bool success, ) = payable(msg.sender).call{value: returnedAmount}("");
            require(success, "ETH transfer failed");
        }

        // calling Policy like a function
        policies[_policyId] = Policy(
            _policyId,
            _coverage, 
            premium, 
            _rainfallAmt, 
            _region,
            deductibleDays,
            0, // initialize days over treshhold with 0
            payable(msg.sender), // owner
            _startTime,
            _endTime,
            false //set has ended as false
        );

        // add policy ID to array for iteration
        allActivePolicies.push(_policyId);

        // emit event
        emit NewPolicy(
            msg.sender, // owner
            _policyId,  
            _region,
            _coverage, 
            premium, 
            deductibleDays,
            duration,
            returnedAmount);
    }

    // Safe trigger function
    function trigger(uint _current_entry) public {
        // loop through all active policies
        for (uint i = 0; i < allActivePolicies.length; ++i) {
            uint policyId = allActivePolicies[i];
            Policy storage p = policies[policyId]; // allow updates with storage

            // check validity of policy:
            if (block.timestamp < p.startTime) {
                // policy has not started -> do nothing
            } else if (block.timestamp > p.startTime && block.timestamp < p.endTime) {
                // valid policy
                if (_current_entry > p.rainfallAmt) {
                        p.daysOverThreshold += 1;  // add 1 to counter
                        affectedPolicies.push(p.policyId);
                        daysOverTreshholdOfAffectedPolicies.push(p.daysOverThreshold);
                } // else: no need to reset counter -> so nothing happens
            } else {
                // Policy has expired -> handle possible payout
                p.hasEnded = true;
                if ((p.daysOverThreshold * 24 * 60 * 60) > p.deductibleDays) { // scale days to seconds
                    // treshold reached -> payout
                    uint payout = ((p.daysOverThreshold * 24 * 60 * 60) -  p.deductibleDays ) * p.coverage; // scale days to seconds
                    // Ensure contract has enough balance
                    uint contractBalance = address(this).balance;
                    if (contractBalance >= payout) {
                        // Attempt to send ETH to the policy owner
                        (bool success, ) = payable(p.owner).call{value: payout}("");
                        emit CoverageTriggered(        
                            policyId,
                            p.owner,
                            block.timestamp,
                            p.coverage,
                            p.deductibleDays,
                            p.daysOverThreshold,
                            payout,
                            success);
                        // Update contract balance
                        if (success) {
                            contractBalance -= payout;
                            p.daysOverThreshold = 0; // reset count
                            // remove ended policy from array in order to reduce itterating through expired policies
                            allActivePolicies[i] = allActivePolicies[allActivePolicies.length - 1];
                            allActivePolicies.pop();
                        }
                    } else {
                        // Not enough balance to pay
                        emit CoverageTriggered(        
                            policyId, 
                            p.owner, 
                            block.timestamp,
                            p.coverage,
                            p.deductibleDays,
                            p.daysOverThreshold,
                            payout, 
                            false);
                    }
                } else {
                    // treshold not reached -> no payout
                    emit CoverageTriggered(
                        policyId,
                        p.owner,
                        block.timestamp,
                        p.coverage,
                        p.deductibleDays,
                        p.daysOverThreshold,
                        0,  // payment
                        true);
                }
            }
        }

        // Emit event for all affected policies
        // check if affectedPolicies array is not empty
        if (affectedPolicies.length > 0) {
            emit addWeatherData(
                block.timestamp, // uint indexed timestamp,
                _current_entry,  // uint dataValue,
                affectedPolicies, // uint[] affectedPolicyIds,
                daysOverTreshholdOfAffectedPolicies // uint[] newCounts
            );
            delete affectedPolicies;
            delete daysOverTreshholdOfAffectedPolicies;
        }
    }

    constructor() payable {
        // constructor is payable, to initialize funds on the smart contract
        insurer = msg.sender;
        // to ensure that only constructor of smart contract can withdraw funds
    }
}
