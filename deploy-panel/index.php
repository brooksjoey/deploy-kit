<?php
/**
 * Deploy-Kit Web Management Panel
 * Main index page for the deployment management interface
 */

// Security headers
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('X-XSS-Protection: 1; mode=block');

// Start session for authentication
session_start();

// Basic configuration
$config = [
    'title' => 'Deploy-Kit Management Panel',
    'version' => '1.0.0',
    'theme' => 'default'
];

// Load configuration if available
if (file_exists('../config/config.json')) {
    $jsonConfig = json_decode(file_get_contents('../config/config.json'), true);
    if ($jsonConfig) {
        $config = array_merge($config, $jsonConfig);
    }
}

// Simple authentication check (in production, use proper authentication)
function isAuthenticated() {
    return isset($_SESSION['authenticated']) && $_SESSION['authenticated'] === true;
}

// Handle login
if (isset($_POST['login'])) {
    $username = $_POST['username'] ?? '';
    $password = $_POST['password'] ?? '';
    
    // Simple demo authentication (replace with proper auth)
    if ($username === 'admin' && $password === 'admin') {
        $_SESSION['authenticated'] = true;
        header('Location: ' . $_SERVER['PHP_SELF']);
        exit;
    } else {
        $error = 'Invalid credentials';
    }
}

// Handle logout
if (isset($_GET['logout'])) {
    session_destroy();
    header('Location: ' . $_SERVER['PHP_SELF']);
    exit;
}

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?php echo htmlspecialchars($config['title']); ?></title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #333;
        }
        .container { 
            max-width: 1200px; 
            margin: 0 auto; 
            padding: 20px; 
        }
        .header {
            background: rgba(255,255,255,0.95);
            padding: 20px;
            border-radius: 10px;
            margin-bottom: 20px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .header h1 {
            color: #2c3e50;
            margin-bottom: 10px;
        }
        .header .subtitle {
            color: #7f8c8d;
            font-size: 14px;
        }
        .dashboard {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }
        .card {
            background: rgba(255,255,255,0.95);
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .card h3 {
            color: #2c3e50;
            margin-bottom: 15px;
            border-bottom: 2px solid #3498db;
            padding-bottom: 5px;
        }
        .tool-link {
            display: block;
            padding: 10px 15px;
            margin: 5px 0;
            background: #3498db;
            color: white;
            text-decoration: none;
            border-radius: 5px;
            transition: background 0.3s;
        }
        .tool-link:hover {
            background: #2980b9;
        }
        .status-info {
            padding: 10px;
            margin: 10px 0;
            border-radius: 5px;
            background: #e8f5e8;
            border-left: 4px solid #27ae60;
        }
        .login-form {
            max-width: 400px;
            margin: 50px auto;
            background: rgba(255,255,255,0.95);
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .form-group {
            margin-bottom: 15px;
        }
        .form-group label {
            display: block;
            margin-bottom: 5px;
            color: #2c3e50;
        }
        .form-group input {
            width: 100%;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 5px;
            font-size: 14px;
        }
        .btn {
            background: #3498db;
            color: white;
            padding: 10px 20px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 14px;
            text-decoration: none;
            display: inline-block;
        }
        .btn:hover {
            background: #2980b9;
        }
        .error {
            color: #e74c3c;
            margin-bottom: 15px;
            padding: 10px;
            background: #ffeaea;
            border-radius: 5px;
        }
        .logout {
            float: right;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <div class="container">
        <?php if (!isAuthenticated()): ?>
            <!-- Login Form -->
            <div class="login-form">
                <h2><?php echo htmlspecialchars($config['title']); ?></h2>
                <p>Please log in to access the deployment panel</p>
                
                <?php if (isset($error)): ?>
                    <div class="error"><?php echo htmlspecialchars($error); ?></div>
                <?php endif; ?>
                
                <form method="POST">
                    <div class="form-group">
                        <label for="username">Username:</label>
                        <input type="text" id="username" name="username" required>
                    </div>
                    <div class="form-group">
                        <label for="password">Password:</label>
                        <input type="password" id="password" name="password" required>
                    </div>
                    <button type="submit" name="login" class="btn">Login</button>
                </form>
                
                <p style="margin-top: 20px; font-size: 12px; color: #7f8c8d;">
                    Demo credentials: admin / admin
                </p>
            </div>
        <?php else: ?>
            <!-- Main Dashboard -->
            <div class="header">
                <h1><?php echo htmlspecialchars($config['title']); ?></h1>
                <div class="subtitle">
                    Version <?php echo htmlspecialchars($config['version']); ?> | 
                    Environment: <?php echo htmlspecialchars($config['environment'] ?? 'production'); ?>
                    <a href="?logout=1" class="logout">Logout</a>
                </div>
            </div>

            <div class="dashboard">
                <!-- Deployment Tools -->
                <div class="card">
                    <h3>🚀 Deployment Tools</h3>
                    <a href="tools/git-cloner.php" class="tool-link">Git Repository Cloner</a>
                    <a href="tools/system-check.php" class="tool-link">System Health Check</a>
                    <a href="tools/log-viewer.php" class="tool-link">Log Viewer</a>
                </div>

                <!-- Quick Actions -->
                <div class="card">
                    <h3>⚡ Quick Actions</h3>
                    <div style="margin: 10px 0;">
                        <button onclick="runCommand('status')" class="btn">Check Status</button>
                        <button onclick="runCommand('deploy')" class="btn">Deploy</button>
                        <button onclick="runCommand('restart')" class="btn">Restart Services</button>
                    </div>
                    <div id="command-output" style="margin-top: 15px; padding: 10px; background: #f8f9fa; border-radius: 5px; font-family: monospace; font-size: 12px; max-height: 200px; overflow-y: auto; display: none;"></div>
                </div>

                <!-- System Information -->
                <div class="card">
                    <h3>📊 System Information</h3>
                    <div class="status-info">
                        <strong>Server:</strong> <?php echo php_uname('n'); ?><br>
                        <strong>PHP Version:</strong> <?php echo PHP_VERSION; ?><br>
                        <strong>Load Average:</strong> <?php echo implode(' ', sys_getloadavg()); ?><br>
                        <strong>Memory Usage:</strong> <?php echo round(memory_get_usage(true) / 1024 / 1024, 2); ?> MB
                    </div>
                </div>

                <!-- Configuration -->
                <div class="card">
                    <h3>⚙️ Configuration</h3>
                    <div style="font-size: 12px; font-family: monospace;">
                        <strong>Deployment Path:</strong> <?php echo htmlspecialchars($config['deploymentPath'] ?? '/var/www/html'); ?><br>
                        <strong>Backup Enabled:</strong> <?php echo ($config['backupEnabled'] ?? true) ? 'Yes' : 'No'; ?><br>
                        <strong>Services:</strong> <?php echo implode(', ', $config['services'] ?? ['nginx', 'php-fpm']); ?>
                    </div>
                </div>
            </div>
        <?php endif; ?>
    </div>

    <script>
        function runCommand(action) {
            const output = document.getElementById('command-output');
            output.style.display = 'block';
            output.innerHTML = 'Running ' + action + '...';
            
            // Simulate command execution (in real implementation, use AJAX to call backend)
            setTimeout(() => {
                let result = '';
                switch(action) {
                    case 'status':
                        result = 'System Status: OK\nServices: nginx (running), php-fpm (running)\nDisk Usage: 45%\nMemory Usage: 60%';
                        break;
                    case 'deploy':
                        result = 'Starting deployment...\nPulling latest code...\nInstalling dependencies...\nRestarting services...\nDeployment completed successfully!';
                        break;
                    case 'restart':
                        result = 'Restarting nginx... OK\nRestarting php-fpm... OK\nAll services restarted successfully!';
                        break;
                }
                output.innerHTML = result.replace(/\n/g, '<br>');
            }, 2000);
        }
    </script>
</body>
</html>