<?php
/**
 * Upload Chat Image API
 * Accepts multipart/form-data with key "image". Returns public URL of saved image.
 */

header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false, 'error' => 'Method not allowed']);
    exit;
}

$upload_dir = __DIR__ . '/../uploads/chat';
if (!is_dir($upload_dir)) {
    if (!@mkdir($upload_dir, 0755, true)) {
        echo json_encode(['success' => false, 'error' => 'Upload directory could not be created']);
        exit;
    }
}

// Client-sent MIME can be wrong (e.g. image_picker sends empty or application/octet-stream), so we validate by extension and getimagesize()
$allowed_mimes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp', 'image/pjpeg', ''];
$allowed_exts = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
$max_size = 5 * 1024 * 1024; // 5 MB

if (empty($_FILES['image']) || $_FILES['image']['error'] !== UPLOAD_ERR_OK) {
    $err = $_FILES['image']['error'] ?? 'no_file';
    echo json_encode(['success' => false, 'error' => 'Upload failed: ' . (is_int($err) ? 'error code ' . $err : $err)]);
    exit;
}

$file = $_FILES['image'];
$type = trim($file['type'] ?? '');
$name = $file['name'] ?? '';
$tmp = $file['tmp_name'] ?? '';

// Accept if MIME is in list. If not (e.g. empty or application/octet-stream from image_picker), allow and validate by getimagesize() below.
$client_ext = strtolower(pathinfo($name, PATHINFO_EXTENSION));
if ($type !== '' && !in_array(strtolower($type), array_map('strtolower', $allowed_mimes))) {
    // Only reject when we have a known-bad extension; empty extension will be validated by getimagesize()
    if ($client_ext !== '' && !in_array($client_ext, $allowed_exts)) {
        echo json_encode(['success' => false, 'error' => 'Invalid file type. Allowed: JPEG, PNG, GIF, WebP']);
        exit;
    }
}
if ($file['size'] > $max_size) {
    echo json_encode(['success' => false, 'error' => 'File too large. Max 5 MB']);
    exit;
}

// Validate that the file is actually an image (works even when extension/MIME is wrong)
$image_type = null;
if (is_uploaded_file($tmp) && function_exists('getimagesize')) {
    $info = @getimagesize($tmp);
    if ($info === false || empty($info[0]) || empty($info[1])) {
        echo json_encode(['success' => false, 'error' => 'File is not a valid image']);
        exit;
    }
    $image_type = isset($info[2]) ? $info[2] : null; // IMAGETYPE_JPEG, IMAGETYPE_PNG, etc.
}

$ext = strtolower(pathinfo($name, PATHINFO_EXTENSION));
if (!in_array($ext, $allowed_exts)) {
    // Infer from getimagesize (image_picker often sends file with no extension)
    $ext = 'jpg';
    if ($image_type !== null) {
        if ($image_type === IMAGETYPE_JPEG) $ext = 'jpg';
        elseif ($image_type === IMAGETYPE_PNG) $ext = 'png';
        elseif ($image_type === IMAGETYPE_GIF) $ext = 'gif';
        elseif ($image_type === IMAGETYPE_WEBP) $ext = 'webp';
    }
}
$name = uniqid('chat_', true) . '.' . $ext;
$path = $upload_dir . '/' . $name;

if (!move_uploaded_file($file['tmp_name'], $path)) {
    echo json_encode(['success' => false, 'error' => 'Failed to save file']);
    exit;
}

// Public URL path (relative to site root). Adjust if your base URL differs.
$url_path = '/uploads/chat/' . $name;
$base_url = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? 'https' : 'http') . '://' . ($_SERVER['HTTP_HOST'] ?? 'portal.gcsewithrosi.co.uk');
$full_url = rtrim($base_url, '/') . $url_path;

echo json_encode([
    'success' => true,
    'image_url' => $full_url,
    'path' => $url_path,
]);
