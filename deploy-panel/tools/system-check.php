<?php
/**
 * Deploy-Kit System Health Check
 * Web interface for monitoring system status and health
 */

// Security check
session_start();
if (!isset($_SESSION['authenticated']) || $_SESSION['authenticated'] !== true) {
    header('Location: ../index.php');
    exit;
}

function getServiceStatus($service) {
    $output = shell_exec("systemctl is-active $service 2>/dev/null");
    return trim($output) === 'active';
}

function formatBytes($bytes, $precision = 2) {
    $units = array('B', 'KB', 'MB', 'GB', 'TB');
    for ($i = 0; $bytes > 1024 && $i < count($units) - 1; $i++) {
        $bytes /= 1024;
    }
    return round($bytes, $precision) . ' ' . $units[$i];
}

function getDiskUsage($path = '/') {
    $bytes = disk_free_space($path);
    $total = disk_total_space($path);
    if ($bytes !== false && $total !== false) {
        $used = $total - $bytes;
        $percentage = round(($used / $total) * 100, 2);
        return [
            'total' => formatBytes($total),
            'used' => formatBytes($used),
            'percentage' => $percentage
        ];
    }
    return null;
}

function getMemoryUsage() {
    $meminfo = file_get_contents('/proc/meminfo');
    preg_match('/MemTotal:\s+(\d+)/', $meminfo, $total);
    preg_match('/MemAvailable:\s+(\d+)/', $meminfo, $available);
    
    if ($total && $available) {
        $total_kb = $total[1];
        $available_kb = $available[1];
        $used_kb = $total_kb - $available_kb;
        $percentage = round(($used_kb / $total_kb) * 100, 2);
        
        return [
            'total' => formatBytes($total_kb * 1024),
            'used' => formatBytes($used_kb * 1024),
            'percentage' => $percentage
        ];
    }
    return null;
}

// Collect system information
$services = ['nginx', 'php7.4-fpm', 'php8.0-fpm', 'redis-server', 'mysql'];
$service_status = [];

foreach ($services as $service) {
    $status = getServiceStatus($service);
    if ($status || shell_exec("systemctl list-unit-files | grep -q '^$service'")) {
        $service_status[] = ['name' => $service, 'status' => $status];
    }
}

$disk_usage = getDiskUsage('/');
$memory_usage = getMemoryUsage();
$load_average = function_exists('sys_getloadavg') ? sys_getloadavg() : [0, 0, 0];
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>System Health Check - Deploy-Kit</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .card { background: #f8f9fa; padding: 15px; border-radius: 8px; border-left: 4px solid #007cba; }
        .card h3 { margin-top: 0; color: #343a40; }
        .status-ok { color: #28a745; font-weight: bold; }
        .status-error { color: #dc3545; font-weight: bold; }
        .progress-bar { width: 100%; height: 20px; background: #e9ecef; border-radius: 10px; overflow: hidden; margin: 5px 0; }
        .progress-fill { height: 100%; transition: width 0.3s ease; }
        .progress-green { background: #28a745; }
        .progress-yellow { background: #ffc107; }
        .progress-red { background: #dc3545; }
        .table { width: 100%; border-collapse: collapse; margin-top: 10px; }
        .table th, .table td { padding: 8px 12px; text-align: left; border-bottom: 1px solid #dee2e6; }
        .table th { background: #e9ecef; }
        .back-link a { color: #007cba; text-decoration: none; }
        .refresh-btn { background: #007cba; color: white; padding: 8px 15px; border: none; border-radius: 4px; cursor: pointer; }
        .metric { display: flex; justify-content: space-between; margin: 5px 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="back-link"><a href="../index.php">← Back to Dashboard</a></div>
        
        <h1>System Health Check</h1>
        <button class="refresh-btn" onclick="location.reload()">🔄 Refresh</button>
        
        <div class="grid">
            <!-- System Resources -->
            <div class="card">
                <h3>💻 System Resources</h3>
                
                <?php if ($memory_usage): ?>
                <div>
                    <div class="metric">
                        <span><strong>Memory:</strong></span>
                        <span><?php echo $memory_usage['percentage']; ?>%</span>
                    </div>
                    <div class="progress-bar">
                        <div class="progress-fill <?php echo $memory_usage['percentage'] > 80 ? 'progress-red' : ($memory_usage['percentage'] > 60 ? 'progress-yellow' : 'progress-green'); ?>" 
                             style="width: <?php echo $memory_usage['percentage']; ?>%"></div>
                    </div>
                    <small><?php echo $memory_usage['used']; ?> of <?php echo $memory_usage['total']; ?></small>
                </div>
                <?php endif; ?>
                
                <?php if ($disk_usage): ?>
                <div style="margin-top: 15px;">
                    <div class="metric">
                        <span><strong>Disk:</strong></span>
                        <span><?php echo $disk_usage['percentage']; ?>%</span>
                    </div>
                    <div class="progress-bar">
                        <div class="progress-fill <?php echo $disk_usage['percentage'] > 80 ? 'progress-red' : ($disk_usage['percentage'] > 60 ? 'progress-yellow' : 'progress-green'); ?>" 
                             style="width: <?php echo $disk_usage['percentage']; ?>%"></div>
                    </div>
                    <small><?php echo $disk_usage['used']; ?> of <?php echo $disk_usage['total']; ?></small>
                </div>
                <?php endif; ?>
                
                <div class="metric">
                    <span><strong>Load:</strong></span>
                    <span><?php echo implode(', ', array_map(function($load) { return number_format($load, 2); }, $load_average)); ?></span>
                </div>
                
                <div class="metric">
                    <span><strong>PHP:</strong></span>
                    <span><?php echo PHP_VERSION; ?></span>
                </div>
            </div>
            
            <!-- Services Status -->
            <div class="card">
                <h3>🔧 Services</h3>
                <table class="table">
                    <thead>
                        <tr><th>Service</th><th>Status</th></tr>
                    </thead>
                    <tbody>
                        <?php foreach ($service_status as $service): ?>
                        <tr>
                            <td><?php echo htmlspecialchars($service['name']); ?></td>
                            <td class="<?php echo $service['status'] ? 'status-ok' : 'status-error'; ?>">
                                <?php echo $service['status'] ? '✓ Running' : '✗ Stopped'; ?>
                            </td>
                        </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</body>
</html>