<?php
/**
 * Deploy-Kit Log Viewer
 * Web interface for viewing deployment and system logs
 */

// Security check
session_start();
if (!isset($_SESSION['authenticated']) || $_SESSION['authenticated'] !== true) {
    header('Location: ../index.php');
    exit;
}

// Available log files
$log_files = [
    'deploy' => '/var/log/deploy-kit/deploy.log',
    'restart' => '/var/log/deploy-kit/restart.log', 
    'setup' => '/var/log/deploy-kit/setup.log',
    'nginx-error' => '/var/log/nginx/error.log',
    'syslog' => '/var/log/syslog'
];

$selected_log = $_GET['log'] ?? 'deploy';
$lines = (int)($_GET['lines'] ?? 50);
$lines = max(10, min(1000, $lines));

$log_content = '';
$log_exists = false;

if (isset($log_files[$selected_log])) {
    $log_path = $log_files[$selected_log];
    
    if (file_exists($log_path) && is_readable($log_path)) {
        $log_exists = true;
        $command = "tail -n {$lines} " . escapeshellarg($log_path);
        $log_content = shell_exec($command) ?: 'Unable to read log file';
    } else {
        $log_content = "Log file not found: {$log_path}";
    }
}

$auto_refresh = isset($_GET['refresh']) && $_GET['refresh'] === '1';
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Log Viewer - Deploy-Kit</title>
    <?php if ($auto_refresh): ?><meta http-equiv="refresh" content="5"><?php endif; ?>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; }
        .controls { margin-bottom: 20px; padding: 15px; background: #f8f9fa; border-radius: 4px; }
        .log-content { 
            background: #1e1e1e; color: #f8f8f2; padding: 15px; border-radius: 4px; 
            font-family: monospace; font-size: 12px; white-space: pre-wrap;
            max-height: 600px; overflow-y: auto;
        }
        .back-link a { color: #007cba; text-decoration: none; }
        button { background: #007cba; color: white; padding: 8px 15px; border: none; border-radius: 4px; cursor: pointer; }
    </style>
</head>
<body>
    <div class="container">
        <div class="back-link"><a href="../index.php">← Back to Dashboard</a></div>
        
        <h1>Log Viewer</h1>
        
        <div class="controls">
            <form method="GET" style="display: inline;">
                <select name="log" onchange="this.form.submit()">
                    <?php foreach ($log_files as $key => $path): ?>
                        <option value="<?php echo $key; ?>" <?php echo $selected_log === $key ? 'selected' : ''; ?>>
                            <?php echo ucfirst(str_replace('-', ' ', $key)); ?>
                        </option>
                    <?php endforeach; ?>
                </select>
                
                <input type="number" name="lines" value="<?php echo $lines; ?>" min="10" max="1000">
                
                <label>
                    <input type="checkbox" name="refresh" value="1" <?php echo $auto_refresh ? 'checked' : ''; ?> onchange="this.form.submit()">
                    Auto-refresh
                </label>
                
                <button type="submit">Update</button>
            </form>
            
            <button onclick="location.reload()">Refresh</button>
        </div>
        
        <div><strong>Status:</strong> <?php echo $log_exists ? 'Available' : 'Not Found'; ?></div>
        
        <div class="log-content"><?php echo htmlspecialchars($log_content); ?></div>
    </div>
</body>
</html>