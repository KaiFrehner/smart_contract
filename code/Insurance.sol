//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;


// initial try to make an insurance contract
// initially check one value is bigger then anohter -> payout. 

contract insurance {
    // define policy. has ID, coverage and premium...
    struct Policy {
        uint policy_id;
        uint coverage; // is paid out when policy is triggered
        uint premium;
        uint rainfallAmt; // rainfall amt treshold, when above, then policy is triggered in micrometer mm*1000
        uint region; 
        uint thresholdForRegion;// number of days to be above rainfallAmt to start qualifying for reimbursement payments
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
    uint[] public all_policies_IDs;

    // state of auction
    uint256 private nextId = 1;

    // Internal arrays to store affected policies and days over threshold
    uint[] internal affectedPolicies;
    uint[] internal daysOverTreshholdOfAffectedPolicies;

    // Events
    // who buys which policy?
    event NewPolicy(
        address indexed owner, 
        uint indexed policy_id,
        uint region,
        uint coverage,
        uint premium,
        uint tresholdForRegion);

    event CoverageTriggered(
        uint policyId,
        address owner,
        uint timestamp,  // date as uint -> UNIX
        uint coverage,
        uint treshold,
        uint dayOverTreshold,
        uint amountPaid,
        bool success
    );

    event addWeatherData(
        uint indexed timestamp,
        uint dataValue,
        uint[] affectedPolicyIds,
        uint[] newCounts
    );

    // house keeping functions
    function withdraw() external returns (uint amount){
        require(msg.sender == insurer, "Not insurer");
        amount = address(this).balance;
        payable(insurer).transfer(amount);
    }

    // Function to get the balance of the contract
    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    function show_all_policy_ids() public view returns (uint[] memory){
        return all_policies_IDs;
    }

    // store all polices by policy id:
    function newPolicy( // add payable for premium payment
    // require laufzeit
    // days bad weather
        uint _coverage, 
        // address payable _owner
        uint _rainfallAmt,
        uint _region,
        uint _startTime,
        uint _endTime
        ) public payable { 
        
        // TODO: add payable... 
        
        // check user input: Validty of policy
        // Policy must be initiated 2 weeks in advande to fullfill stochasticity of an (parametric) insurance contract
        //require(_startTime > block.timestamp + (14 * 24 * 60 * 60)); commented for testing

        // manage maximum duration of 91 day (source: Helvetia):
        require(_endTime < (_startTime +(91 * 24 * 60 * 60)), "Maximum contract length is 91 days!");

        // manage regions input
        require(_region >= 1 && _region <= 5, "Invalid region");

        // manage policy ID
        uint _policy_id = nextId++;
        // maybe build check to see if this policy id already exists?

        // how long is the trip:
        uint duration = _endTime - _startTime;

        // get treshold for Region
        uint thresholdForRegion;
        if (_region == 1) {
            thresholdForRegion = uint((0 * duration + 3) / 7); // rounding
        } else if (_region == 2) {
            thresholdForRegion = uint((1 * duration + 3) / 7);
        } else if (_region == 3) {
            thresholdForRegion = uint((2 * duration + 3) / 7);
        } else if (_region == 4) {
            thresholdForRegion = uint((3 * duration + 3) / 7);
        } else if (_region == 5) {
            thresholdForRegion = uint((4 * duration + 3) / 7);
        }

        // calculate premium (this is a simple implementation of a premium)
        // to act as an idea. Most likely an insurance company will not provide this in a public smart contract.
        // this is simply implemented for testing purposes 
        // example: premium = _coverage * (duration - thresholdForRegion) * 1/10 * _region * 11/10;
        uint premium = _coverage * (duration - thresholdForRegion) * _region * 11/100;
        // simple Idea: higher coverage increases premium
        // higher treshold decreases premium
        // longer trip increases premium
        // the larger the region, the higher the probablity for rain, multiplied with chance for rain of 10% (estimate)
        // 1.1 is a factor to cover the costs of insurance
        
        // check if paid premium is sufficient
        require(msg.value >= premium);
        // refund if more than premium is paid
        if (msg.value > premium) {
            payable(msg.sender).transfer(msg.value - premium);
        }

        // calling Policy like a function
        policies[_policy_id] = Policy(
            _policy_id,
            _coverage, 
            premium, 
            _rainfallAmt, 
            _region,
            thresholdForRegion,
            0, // initialize days over treshhold with 0
            payable(msg.sender),
            _startTime,
            _endTime,
            false //set has ended as false
        );

        // add policy ID to array for iteration
        all_policies_IDs.push(_policy_id);

        // emit event
        emit NewPolicy(
            msg.sender, // owner
            _policy_id,  
            _region,
            _coverage, 
            premium, 
            thresholdForRegion);
    }

    // Safe trigger function
    function trigger(uint _current_entry) public {
        uint contractBalance = address(this).balance;

        for (uint i = 0; i < all_policies_IDs.length; ++i) {
            uint policyId = all_policies_IDs[i];
            Policy storage p = policies[policyId]; // allow updates with storage

            // check validity of policy:

            if (block.timestamp < p.startTime) {
                // policy has not started -> do nothing
            } else if (block.timestamp > p.startTime && block.timestamp < p.endTime) {
                // valid policy
                if (_current_entry > p.rainfallAmt) {
                        p.daysOverThreshold += 1;  // add 1 to counter
                        affectedPolicies.push(p.policy_id);
                        daysOverTreshholdOfAffectedPolicies.push(p.daysOverThreshold);
                } // else: no need to reset counter -> so nothing happens
            } else {
                // Policy has expired -> handle possible payout
                p.hasEnded = true;
                if (p.daysOverThreshold > p.thresholdForRegion) {
                    // treshold reached -> payout
                    uint payout = (p.daysOverThreshold -  p.thresholdForRegion ) * p.coverage;
                    // Ensure contract has enough balance
                    if (contractBalance >= payout) {
                        // Attempt to send ETH to the policy owner
                        (bool success, ) = payable(p.owner).call{value: payout}("");
                        emit CoverageTriggered(        
                            policyId,
                            p.owner,
                            block.timestamp,
                            p.coverage,
                            p.thresholdForRegion,
                            p.daysOverThreshold,
                            payout,
                            success);
                        // Update contract balance
                        if (success) {
                            contractBalance -= payout;
                            p.daysOverThreshold = 0;} // reset count
                    } else {
                        // Not enough balance to pay
                        emit CoverageTriggered(        
                            policyId, 
                            p.owner, 
                            block.timestamp,
                            p.coverage,
                            p.thresholdForRegion,
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
                        p.thresholdForRegion,
                        p.daysOverThreshold,
                        0,  // payment
                        false);
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


}

/*
input weather data...
Test function, as weather is slow...
in real life use an oracle... 
*/