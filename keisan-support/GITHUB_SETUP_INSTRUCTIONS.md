# GitHub Setup Instructions for Keisan Support Page

Follow these steps to create a public GitHub repository and enable GitHub Pages for your Keisan app support page.

## Step 1: Create GitHub Repository

1. Go to [GitHub.com](https://github.com) and sign in to your account
2. Click the "+" button in the top right corner and select "New repository"
3. Fill in the repository details:
   - **Repository name:** `keisan-support`
   - **Description:** `Support page for Keisan salary calculation app`
   - **Visibility:** Make sure "Public" is selected (required for free GitHub Pages)
   - **Initialize:** Leave unchecked (we already have files)
4. Click "Create repository"

## Step 2: Upload Files to GitHub

You have two options:

### Option A: Using Git Command Line (Recommended)
```bash
# Navigate to the keisan-support folder
cd /Users/mankurt/Downloads/ArEady/keisan/keisan-support

# Add your GitHub repository as remote
git remote add origin https://github.com/mankurt01/keisan-support.git

# Push to GitHub
git push -u origin main
```

### Option B: Using GitHub Web Interface
1. On your new repository page, click "uploading an existing file"
2. Drag and drop both `index.html` and `README.md` files
3. Add commit message: "Add Keisan App support page"
4. Click "Commit changes"

## Step 3: Enable GitHub Pages

1. Go to your repository on GitHub
2. Click on "Settings" tab
3. Scroll down to "Pages" section in the left sidebar
4. Under "Source", select "Deploy from a branch"
5. Choose "main" branch and "/ (root)" folder
6. Click "Save"

## Step 4: Get Your Support URL

After enabling GitHub Pages, your support page will be available at:

```
https://mankurt01.github.io/keisan-support
```

It may take a few minutes for the page to become available.

## Step 5: Test Your Support Page

1. Wait 2-3 minutes after enabling GitHub Pages
2. Visit your support URL
3. Verify the page loads correctly
4. Test the email link works

## Step 6: Update Your App

Once you confirm your support URL works, you'll need to update your app's support URL in the `lib/constants/support_info.dart` file.

**Your final support URL will be:**
`https://mankurt01.github.io/keisan-support`

## Troubleshooting

- **Page not loading:** Wait a few more minutes, GitHub Pages can take up to 10 minutes to deploy
- **404 error:** Make sure your repository is public and GitHub Pages is enabled
- **Styling issues:** Check that both `index.html` and any CSS files were uploaded correctly

## Need Help?

If you encounter any issues during setup, please let me know your GitHub username and I can provide more specific instructions.
