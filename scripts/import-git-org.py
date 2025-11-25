import requests
import argparse
import os

def list_repos(org_name, token):
    url = f"https://api.github.com/orgs/{org_name}/repos"
    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json"
    }
    response = requests.get(url, headers=headers)
    repos = []

    while response.status_code == 200:
        repos.extend(response.json())
        if 'next' in response.links:
            response = requests.get(response.links['next']['url'], headers=headers)
        else:
            break

    if response.status_code != 200:
        raise Exception(f"Failed to fetch repositories: {response.status_code} {response.text}")
    return repos

def main():
    token = os.getenv("GITHUB_TOKEN")
    if token is None:
        raise Exception("GITHUB_TOKEN environment variable not set")
    parser = argparse.ArgumentParser(description="List GitHub organization repositories.")
    parser.add_argument("org_name", help="GitHub organization name")
    args = parser.parse_args()

    try:
        repos = list_repos(args.org_name, token)
        for repo in repos:
            print(f"{repo['name']}: {repo['html_url']}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()