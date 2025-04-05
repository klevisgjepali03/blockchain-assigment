// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


contract EscrowContract {
    mapping(uint256 => uint256) public escrowedFunds;
    mapping(uint256 => address payable) public freelancers;
    
    event FundsDeposited(uint256 indexed jobId, uint256 amount);
    event FundsReleased(uint256 indexed jobId, uint256 amount, address freelancer);
    
    function createEscrow(uint256 _jobId, address payable _freelancer) external payable {
        require(msg.value > 0, "Must send funds to escrow");
        require(escrowedFunds[_jobId] == 0, "Escrow already exists for this job");
        require(_freelancer != address(0), "Invalid freelancer address");
        
        escrowedFunds[_jobId] = msg.value;
        freelancers[_jobId] = _freelancer;
        
        emit FundsDeposited(_jobId, msg.value);
    }
    
    function releaseFunds(uint256 _jobId) external {
        uint256 amount = escrowedFunds[_jobId];
        address payable freelancer = freelancers[_jobId];
        
        require(amount > 0, "No funds in escrow for this job");
        require(freelancer != address(0), "No freelancer assigned");
        
        escrowedFunds[_jobId] = 0;
        freelancers[_jobId] = payable(address(0));
        
        (bool sent, ) = freelancer.call{value: amount}("");
        require(sent, "Failed to send funds to freelancer");
        
        emit FundsReleased(_jobId, amount, freelancer);
    }
}

contract JobContract {
    struct Job {
        string description;
        uint256 budget;
        address client;
        address freelancer;
        bool completed;
    }
    
    uint256 public jobCounter;
    mapping(uint256 => Job) public jobs;
    EscrowContract public escrowContract;
    
    event JobCreated(uint256 indexed jobId, string description, uint256 budget, address client);
    event JobAssigned(uint256 indexed jobId, address freelancer);
    event JobCompleted(uint256 indexed jobId);
    
    constructor(address _escrowContractAddress) {
        require(_escrowContractAddress != address(0), "Invalid escrow contract address");
        escrowContract = EscrowContract(_escrowContractAddress);
    }
    
    function createJob(string memory _description, uint256 _budget) external {
        require(_budget > 0, "Budget must be greater than 0");
        
        jobCounter++;
        jobs[jobCounter] = Job({
            description: _description,
            budget: _budget,
            client: msg.sender,
            freelancer: address(0),
            completed: false
        });
        
        emit JobCreated(jobCounter, _description, _budget, msg.sender);
    }
    
    function assignFreelancer(uint256 _jobId, address _freelancer) external payable {
        Job storage job = jobs[_jobId];
        require(job.client == msg.sender, "Only client can assign freelancer");
        require(job.freelancer == address(0), "Freelancer already assigned");
        require(!job.completed, "Job already completed");
        require(_freelancer != address(0), "Invalid freelancer address");
        require(msg.value == job.budget, "Must send exact budget amount");
        
        job.freelancer = _freelancer;
        
        escrowContract.createEscrow{value: msg.value}(_jobId, payable(_freelancer));
        
        emit JobAssigned(_jobId, _freelancer);
    }
    
    function markJobCompleted(uint256 _jobId) external {
        Job storage job = jobs[_jobId];
        require(job.client == msg.sender, "Only client can complete job");
        require(job.freelancer != address(0), "No freelancer assigned");
        require(!job.completed, "Job already completed");
        
        job.completed = true;
        escrowContract.releaseFunds(_jobId);
        
        emit JobCompleted(_jobId);
    }
}