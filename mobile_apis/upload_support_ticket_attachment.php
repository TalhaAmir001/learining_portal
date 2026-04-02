<?php
/**
 * Upload Support Ticket Attachment
 * Accepts multipart/form-data with key "file". Saves to uploads/support-attachments.
 * Returns file_url (path or full URL for storage in support_tickets.attachment or support_ticket_replies.attachment).
 */

header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false, 'error' => 'Method not allowed']);
    exit;
}

$upload_dir = __DIR__ . '/../uploads/support-attachments';
if (!is_dir($upload_dir)) {
    if (!@mkdir($upload_dir, 0755, true)) {
        echo json_encode(['success' => false, 'error' => 'Upload directory could not be created']);
        exit;
    }
}

$allowed_exts = [
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv', 'rtf',
    'jpg', 'jpeg', 'png', 'gif', 'webp',
];
$max_size = 10 * 1024 * 1024; // 10 MB

$file_key = 'file';
if (empty($_FILES[$file_key]) || $_FILES[$file_key]['error'] !== UPLOAD_ERR_OK) {
    $err = $_FILES[$file_key]['error'] ?? 'no_file';
    echo json_encode(['success' => false, 'error' => 'Upload failed: ' . (is_int($err) ? 'error code ' . $err : $err)]);
    exit;
}

$file = $_FILES[$file_key];
$name = $file['name'] ?? '';
$tmp = $file['tmp_name'] ?? '';

$ext = strtolower(pathinfo($name, PATHINFO_EXTENSION));
if ($ext === '' || !in_array($ext, $allowed_exts)) {
    echo json_encode(['success' => false, 'error' => 'Invalid file type. Allowed: documents and images.']);
    exit;
}
if ($file['size'] > $max_size) {
    echo json_encode(['success' => false, 'error' => 'File too large. Max 10 MB']);
    exit;
}

$safe_name = preg_replace('/[^a-zA-Z0-9._-]/', '_', basename($name, '.' . $ext));
$save_name = bin2hex(random_bytes(8)) . '_' . substr($safe_name, 0, 32) . '.' . $ext;
$path = $upload_dir . '/' . $save_name;

if (!move_uploaded_file($file['tmp_name'], $path)) {
    echo json_encode(['success' => false, 'error' => 'Failed to save file']);
    exit;
}

$url_path = '/uploads/support-attachments/' . $save_name;
$base_url = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? 'https' : 'http') . '://' . ($_SERVER['HTTP_HOST'] ?? 'portal.gcsewithrosi.co.uk');
$full_url = rtrim($base_url, '/') . $url_path;

echo json_encode([
    'success' => true,
    'file_url' => $full_url,
    'path' => $url_path,
    'filename' => $name,
]);
