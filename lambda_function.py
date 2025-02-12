import os
import boto3
import json
import logging
import subprocess
from git import Repo
from botocore.exceptions import ClientError
from typing import Dict, Any, Optional

# Configure logging with structured format
logger = logging.getLogger()
logger.setLevel(os.environ.get('LOG_LEVEL', 'INFO'))
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
for handler in logger.handlers:
    handler.setFormatter(formatter)

def get_github_token() -> str:
    """
    Retrieve GitHub token from AWS Secrets Manager securely
    
    Returns:
        str: The GitHub token
        
    Raises:
        ClientError: If there's an error retrieving the secret
    """
    try:
        client = boto3.client("secretsmanager")
        response = client.get_secret_value(SecretId=os.environ["AWS_SECRET_ID"])
        return response["SecretString"]
    except ClientError as e:
        logger.error(f"Failed to retrieve secret: {str(e)}")
        raise

def setup_repo(token: str, repo_url: str, branch: str) -> Repo:
    """
    Clone repository and set up git configuration
    
    Args:
        token: GitHub token for authentication
        repo_url: URL of the repository to clone
        branch: Branch to clone
        
    Returns:
        Repo: The cloned repository object
        
    Raises:
        Exception: If there's an error during repository setup
    """
    repo_dir = "/tmp/repo"
    try:
        if os.path.exists(repo_dir):
            logger.info("Cleaning up existing repo directory")
            subprocess.run(["rm", "-rf", repo_dir], check=True)
        
        logger.info("Cloning repository")  # Don't log the URL as it contains the token
        repo = Repo.clone_from(repo_url, repo_dir, branch=branch)
        
        # Configure git user for commits
        with repo.config_writer() as git_config:
            git_config.set_value('user', 'name', 'Commitron Bot')
            git_config.set_value('user', 'email', 'bot@commitron.com')
        
        return repo
    except Exception as e:
        logger.error(f"Failed to set up repository: {str(e)}")
        raise

def update_counter(file_path: str) -> int:
    """
    Read and increment counter in the file
    
    Args:
        file_path: Path to the counter file
        
    Returns:
        int: The new counter value
        
    Raises:
        Exception: If there's an error updating the counter
    """
    try:
        counter = 1
        if os.path.exists(file_path):
            with open(file_path, "r") as file:
                content = file.read().strip()
                try:
                    counter = int(content) + 1
                except ValueError:
                    logger.warning(f"Invalid counter value in file: {content}, resetting to 1")
        
        with open(file_path, "w") as file:
            file.write(str(counter))
        
        return counter
    except Exception as e:
        logger.error(f"Failed to update counter: {str(e)}")
        raise

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler function
    
    Args:
        event: Lambda event object
        context: Lambda context object
        
    Returns:
        Dict[str, Any]: Response object with status and message
    """
    try:
        # Input validation
        required_env_vars = ['GITHUB_REPO', 'FILE_PATH', 'BRANCH', 'AWS_SECRET_ID']
        missing_vars = [var for var in required_env_vars if not os.environ.get(var)]
        if missing_vars:
            raise ValueError(f"Missing required environment variables: {', '.join(missing_vars)}")
        
        # Get configuration from environment variables
        github_repo = os.environ['GITHUB_REPO']
        file_path = os.environ['FILE_PATH']
        branch = os.environ['BRANCH']
        
        # Get GitHub token and construct repo URL
        token = get_github_token()
        repo_url = f"https://{token}@github.com/{github_repo}.git"
        
        # Set up repository
        repo = setup_repo(token, repo_url, branch)
        counter_file_path = os.path.join("/tmp/repo", file_path)
        
        # Update counter
        counter = update_counter(counter_file_path)
        
        # Commit and push changes
        repo.git.add(counter_file_path)
        commit_message = f"Automated commit: Increment counter to {counter}"
        repo.index.commit(commit_message)
        logger.info("Created commit")  # Don't log the full message as it might contain sensitive info
        
        repo.remote(name="origin").push()
        logger.info("Successfully pushed changes to remote repository")
        
        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": f"Counter updated to {counter}",
                "repository": github_repo,
                "branch": branch
            })
        }
        
    except Exception as e:
        logger.error(f"Lambda execution failed: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps({
                "error": str(e)
            })
        }
