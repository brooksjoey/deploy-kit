<?php
/**
 * Deploy-Kit Git Repository Cloner
 * Web interface for cloning repositories
 */

// Security check
session_start();
if (!isset($_SESSION['authenticated']) || $_SESSION['authenticated'] !== true) {
    header('Location: ../index.php');
    exit;
}

$message = '';
$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $repo_url = trim($_POST['repo_url'] ?? '');
    $target_dir = trim($_POST['target_dir'] ?? '');
    $branch = trim($_POST['branch'] ?? 'main');
    
    if (empty($repo_url) || empty($target_dir)) {
        $error = 'Repository URL and target directory are required';
    } else {
        // Validate repository URL
        if (!filter_var($repo_url, FILTER_VALIDATE_URL) && !preg_match('/^git@/', $repo_url)) {
            $error = 'Invalid repository URL';
        } else {
            // Sanitize target directory
            $target_dir = realpath('/var/www/html') . '/' . basename($target_dir);
            
            // Execute git clone
            $command = sprintf(
                'cd %s && git clone -b %s %s %s 2>&1',
                escapeshellarg(dirname($target_dir)),
                escapeshellarg($branch),
                escapeshellarg($repo_url),
                escapeshellarg(basename($target_dir))
            );
            
            $output = shell_exec($command);
            
            if (is_dir($target_dir . '/.git')) {
                $message = "Repository cloned successfully to $target_dir";
            } else {
                $error = "Clone failed: " . htmlspecialchars($output);
            }
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Git Repository Cloner - Deploy-Kit</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; }
        .form-group { margin-bottom: 15px; }
        label { display: block; margin-bottom: 5px; font-weight: bold; }
        input[type="text"], input[type="url"] { width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px; }
        button { background: #007cba; color: white; padding: 10px 20px; border: none; border-radius: 4px; cursor: pointer; }
        button:hover { background: #005a87; }
        .message { padding: 10px; margin: 10px 0; border-radius: 4px; }
        .success { background: #d4edda; border: 1px solid #c3e6cb; color: #155724; }
        .error { background: #f8d7da; border: 1px solid #f5c6cb; color: #721c24; }
        .back-link { margin-bottom: 20px; }
        .back-link a { color: #007cba; text-decoration: none; }
    </style>
</head>
<body>
    <div class="container">
        <div class="back-link">
            <a href="../index.php">← Back to Dashboard</a>
        </div>
        
        <h1>Git Repository Cloner</h1>
        <p>Clone a Git repository to the deployment directory.</p>
        
        <?php if ($message): ?>
            <div class="message success"><?php echo htmlspecialchars($message); ?></div>
        <?php endif; ?>
        
        <?php if ($error): ?>
            <div class="message error"><?php echo htmlspecialchars($error); ?></div>
        <?php endif; ?>
        
        <form method="POST">
            <div class="form-group">
                <label for="repo_url">Repository URL:</label>
                <input type="url" id="repo_url" name="repo_url" 
                       value="<?php echo htmlspecialchars($_POST['repo_url'] ?? ''); ?>"
                       placeholder="https://github.com/user/repository.git" required>
            </div>
            
            <div class="form-group">
                <label for="target_dir">Target Directory:</label>
                <input type="text" id="target_dir" name="target_dir" 
                       value="<?php echo htmlspecialchars($_POST['target_dir'] ?? ''); ?>"
                       placeholder="my-app" required>
                <small>Directory will be created in /var/www/html/</small>
            </div>
            
            <div class="form-group">
                <label for="branch">Branch:</label>
                <input type="text" id="branch" name="branch" 
                       value="<?php echo htmlspecialchars($_POST['branch'] ?? 'main'); ?>"
                       placeholder="main">
            </div>
            
            <button type="submit">Clone Repository</button>
        </form>
        
        <div style="margin-top: 30px; padding: 15px; background: #e9ecef; border-radius: 4px;">
            <h3>Usage Examples:</h3>
            <ul>
                <li><strong>GitHub:</strong> https://github.com/user/repo.git</li>
                <li><strong>GitLab:</strong> https://gitlab.com/user/repo.git</li>
                <li><strong>SSH:</strong> git@github.com:user/repo.git</li>
            </ul>
        </div>
    </div>
</body>
</html>