//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

//import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

struct ProjectCreator { 
   uint256 totalJobCost;
   uint16 jobs;
   uint256 jobTimeLimit;
   uint256[] jobsIssued;//?
   string tokenURI;
   uint16 jobsMinted;
   uint16 jobsCompleted;
}

contract workToken is Ownable, ERC721URIStorage, KeeperCompatibleInterface{
    using SafeERC20 for IERC20;

    uint256 public startTotalJobCost;
    uint16 public jobLimit;
    uint256 public tokenCounter;
    IERC20 public stableCoin;
    enum tokenStatus{unFulfilled, fulfilled, expired, flagged}

    mapping(uint256 => tokenStatus) public tokenIdToStatus;
    mapping(uint256 => address) public tokenIdToProjectCreator;
    mapping(uint256 => uint256) public tokenIdToExpiryTime;

    mapping(address => ProjectCreator) public ProjectCreators;

    constructor() ERC721("WorkToken","WRK"){
        tokenCounter = 0;
        startTotalJobCost = 55;
        jobLimit = 10;
    }

    function setTokenAddresses(address _stableCoinAddress) external onlyOwner{
        stableCoin = IERC20(_stableCoinAddress);
    }
    
    function mintNFT(address ProjectCreatorAddress) public returns (uint256){//
        require(ProjectCreators[ProjectCreatorAddress].jobsMinted <= ProjectCreators[ProjectCreatorAddress].jobs);
        tokenIdToStatus[tokenCounter] = tokenStatus(0);
        tokenIdToProjectCreator[tokenCounter] = ProjectCreatorAddress;
        tokenIdToExpiryTime[tokenCounter] = block.timestamp + ProjectCreators[ProjectCreatorAddress].jobTimeLimit;

        ProjectCreators[ProjectCreatorAddress].jobsIssued.push(tokenCounter);
        ProjectCreators[ProjectCreatorAddress].jobsMinted++;

        uint256 jobCost = 10 ** 6 * ProjectCreators[ProjectCreatorAddress].totalJobCost / ProjectCreators[ProjectCreatorAddress].jobs;

        stableCoin.safeTransferFrom(msg.sender, ProjectCreatorAddress, jobCost);

        _safeMint(msg.sender, tokenCounter);
        _setTokenURI(tokenCounter, ProjectCreators[ProjectCreatorAddress].tokenURI);
        tokenCounter++;
        return tokenCounter - 1;
    }

    function newProjectCreator(uint16 jobs, uint256 jobTimeLimit, string memory tokenURI) public {
        require(ProjectCreators[msg.sender].totalJobCost == 0);
        ProjectCreators[msg.sender].totalJobCost = startTotalJobCost;
        ProjectCreatorChangeJob(jobs, jobTimeLimit, tokenURI);
    }

    function ProjectCreatorChangeJob(uint16 jobs, uint256 jobTimeLimit, string memory tokenURI) public {
        require(jobs <= jobLimit && jobs > 0);
        require(ProjectCreators[msg.sender].totalJobCost != 0);
        ProjectCreators[msg.sender].jobs = jobs;
        ProjectCreators[msg.sender].jobTimeLimit = jobTimeLimit;
        ProjectCreators[msg.sender].tokenURI = tokenURI;
        ProjectCreators[msg.sender].jobsCompleted = 0;//jobsMinted
        ProjectCreators[msg.sender].jobsMinted = 0;
    }

    function getProjectCreator(address ProjectCreator) public view returns (ProjectCreator memory) {
        return ProjectCreators[ProjectCreator];
    }

    function completeJob(uint256 jobIndex) public { // add modifyer
        address ProjectCreator = tokenIdToProjectCreator[jobIndex];
        
        tokenIdToStatus[jobIndex] = tokenStatus(1);
        if(keccak256(abi.encodePacked(ProjectCreators[ProjectCreator].tokenURI)) == keccak256(abi.encodePacked(tokenURI(jobIndex)))) {
            ProjectCreators[ProjectCreator].jobsCompleted++;
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
    
    function upgradeProjectCreator() public {
        if(ProjectCreators[msg.sender].jobsCompleted == ProjectCreators[msg.sender].jobs){
            ProjectCreators[msg.sender].totalJobCost = ProjectCreators[msg.sender].totalJobCost * 3 / 2;
            ProjectCreators[msg.sender].jobsCompleted = 0;
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
