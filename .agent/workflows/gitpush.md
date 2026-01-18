---
description: Push changes to all modified repositories in bibliotech
---

This workflow iterates through all git repositories in the parent directory (`../`) and pushes changes if they have modifications or unpushed commits.

**Usage:**
`@agent /gitpush [COMMIT_MESSAGE]`

**Steps:**

1. **Iterate and Push**
    - Run the following script:

    ```bash
    # Store the starting directory
    START_DIR=$(pwd)
    # Message is the first argument, or defaults to "update"
    MSG="${1:-update}"
    
    echo "🚀 Starting multi-repo git push..."
    
    # Iterate through all subdirectories in the parent folder (Sites/bibliotech)
    # We assume 'bibliogenius-app' is where this runs, so we go up one level
    cd ..
    
    for d in */ ; do
        if [ -d "$d/.git" ]; then
            cd "$d"
            REPO_NAME=${d%/}
            
            # Check for changes (staged, unstaged, or untracked)
            if [ -n "$(git status --porcelain)" ]; then
                echo "📦 Changes found in $REPO_NAME"
                git add .
                git commit -m "$MSG"
                git push
                echo "✅ Pushed $REPO_NAME"
            # Check for unpushed commits
            elif [ -n "$(git cherry -v)" ]; then
                 echo "⬆️  Unpushed commits in $REPO_NAME"
                 git push
                 echo "✅ Pushed $REPO_NAME"
            else
                 echo "zzz No changes in $REPO_NAME"
            fi
            
            cd ..
        fi
    done
    
    # Return to original dir
    cd "$START_DIR"
    echo "🎉 Done!"
    ```
