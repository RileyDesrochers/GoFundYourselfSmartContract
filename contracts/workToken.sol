//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";

struct ProjectCreater { 
   uint256 totalJobCost;
   uint16 jobs;
   uint256 jobTimeLimit;
   uint256[] jobsIssued;//?
   string tokenURI;
   uint16 jobsMinted;
   uint16 jobsCompleted;
}

contract workToken is ERC721URIStorage, KeeperCompatibleInterface{
    uint256 public startTotalJobCost;
    uint16 public jobLimit;
    uint256 public tokenCounter;
    IERC20 public stableCoin;
    enum tokenStatus{unFulfilled, fulfilled, expired, flagged}

    mapping(uint256 => tokenStatus) public tokenIdToStatus;
    mapping(uint256 => address) public tokenIdToProjectCreater;
    mapping(uint256 => uint256) public tokenIdToExpiryTime;

    mapping(address => ProjectCreater) public ProjectCreaters;

    constructor() ERC721("WorkToken","WRK"){
        tokenCounter = 0;
        startTotalJobCost = 55;
        jobLimit = 10;
        //stableCoin = IERC20(_stableCoinAddress);
    }

    function approveFunds() public {
        stableCoin.approve(msg.sender, 1 * 10 ** 15);
    }
    
    function mintNFT(address ProjectCreaterAddress) public returns (uint256){ // make payable, check job limit
        require(ProjectCreaters[ProjectCreaterAddress].jobsMinted <= ProjectCreaters[ProjectCreaterAddress].jobs);
        tokenIdToStatus[tokenCounter] = tokenStatus(0);
        tokenIdToProjectCreater[tokenCounter] = ProjectCreaterAddress;
        tokenIdToExpiryTime[tokenCounter] = block.timestamp + ProjectCreaters[ProjectCreaterAddress].jobTimeLimit;

        ProjectCreaters[ProjectCreaterAddress].jobsIssued.push(tokenCounter);
        ProjectCreaters[ProjectCreaterAddress].jobsMinted++;

        uint256 jobCost = 10 ** 6 * ProjectCreaters[ProjectCreaterAddress].totalJobCost / ProjectCreaters[ProjectCreaterAddress].jobs;

        //require(stableCoin.balanceOf(msg.sender) > jobCost);
        stableCoin.transferFrom(msg.sender, ProjectCreaterAddress, jobCost);// is this even safe?

        //transfer payment

        _safeMint(msg.sender, tokenCounter);
        _setTokenURI(tokenCounter, ProjectCreaters[ProjectCreaterAddress].tokenURI);
        tokenCounter++;
        return tokenCounter - 1;
    }

    function newProjectCreater(uint16 jobs, uint256 jobTimeLimit, string memory tokenURI) public {
        require(ProjectCreaters[msg.sender].totalJobCost == 0);
        ProjectCreaters[msg.sender].totalJobCost = startTotalJobCost;
        projectCreaterChangeJob(jobs, jobTimeLimit, tokenURI);
    }

    function projectCreaterChangeJob(uint16 jobs, uint256 jobTimeLimit, string memory tokenURI) public {
        require(jobs <= jobLimit && jobs > 0);
        require(ProjectCreaters[msg.sender].totalJobCost != 0);
        ProjectCreaters[msg.sender].jobs = jobs;
        ProjectCreaters[msg.sender].jobTimeLimit = jobTimeLimit;
        ProjectCreaters[msg.sender].tokenURI = tokenURI;
        ProjectCreaters[msg.sender].jobsCompleted = 0;//jobsMinted
        ProjectCreaters[msg.sender].jobsMinted = 0;
    }

    function getProjectCreater(address projectCreater) public view returns (ProjectCreater memory) {
        return ProjectCreaters[projectCreater];
    }

    function completeJob(uint256 jobIndex) public { // add modifyer
        address projectCreater = tokenIdToProjectCreater[jobIndex];
        
        tokenIdToStatus[jobIndex] = tokenStatus(1);
        if(keccak256(abi.encodePacked(ProjectCreaters[projectCreater].tokenURI)) == keccak256(abi.encodePacked(tokenURI(jobIndex)))) {
            ProjectCreaters[projectCreater].jobsCompleted++;
        }
    }

    function sliceUint(bytes memory bs, uint start) internal pure returns (uint){
        require(bs.length >= start + 32, "slicing out of range");
        uint x;
        assembly {
            x := mload(add(bs, add(0x20, start)))
        }
        return x;
    }

    function badJob(uint256 jobIndex) public { // add modifyer
        tokenIdToStatus[jobIndex] = tokenStatus(3);
    }
    
    function upgradeProjectCreater() public {
        if(ProjectCreaters[msg.sender].jobsCompleted == ProjectCreaters[msg.sender].jobs){
            ProjectCreaters[msg.sender].totalJobCost = ProjectCreaters[msg.sender].totalJobCost * 3 / 2;
            ProjectCreaters[msg.sender].jobsCompleted = 0;
        }
    }


    function checkUpkeep(bytes calldata /*checkData*/) external view override returns (bool upkeepNeeded, bytes memory performData) {
        for (uint256 i=0; i<tokenCounter; i++) {
            if(tokenIdToExpiryTime[i] > block.timestamp){
                upkeepNeeded = true;
                performData = abi.encodePacked(i);
            } 
        }
        upkeepNeeded = false;
    }

    function performUpkeep(bytes calldata performData) external override {
        uint256 i = sliceUint(performData, 0);
        tokenIdToStatus[i] = tokenStatus(2);
    }
}
