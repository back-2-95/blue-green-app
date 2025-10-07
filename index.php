<?php

echo "<h1>Hello World! This is a test</h1>";

// Echo environmental variables which start with TEST_
echo "<h2>Environmental Variables</h2>";
foreach (getenv() as $key => $value) {
    if (str_starts_with($key, 'TEST_')) {  // PHP 8+
        echo "<p><strong>" . htmlspecialchars($key) . "</strong>: " . htmlspecialchars($value) . "</p>";
    }
}

$color = getenv('TEST_INSTANCE');

// Display HTTP request headers in a table
echo "<h2>Request Headers</h2>";
echo "<table border='1' cellpadding='10' cellspacing='0' style='border-collapse: collapse;'>";
echo "<thead style='color:white;background-color:".$color."'><tr><th>Header</th><th>Value</th></tr></thead>";
echo "<tbody>";

// Get all headers
if (function_exists('getallheaders')) {
    $headers = getallheaders();
} else {
    // Fallback for servers where getallheaders() is not available
    $headers = [];
    foreach ($_SERVER as $key => $value) {
        if (str_starts_with($key, 'HTTP_')) {
            $header = str_replace(' ', '-', ucwords(str_replace('_', ' ', strtolower(substr($key, 5)))));
            $headers[$header] = $value;
        }
    }
}

// Display headers in table rows
foreach ($headers as $header => $value) {
    echo "<tr>";
    echo "<td><strong>" . htmlspecialchars($header) . "</strong></td>";
    echo "<td>" . htmlspecialchars($value) . "</td>";
    echo "</tr>";
}

echo "</tbody>";
echo "</table>";
