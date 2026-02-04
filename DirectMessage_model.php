<?php

if (!defined('BASEPATH')) {
    exit('No direct script access allowed');
}

class DirectMessage_model extends MY_Model
{
    protected $current_session;

    public function __construct()
    {
        parent::__construct();
        $this->current_session = $this->setting_model->getCurrentSession();
        $this->current_date    = $this->setting_model->getDateYmd();
    }

    /**
     * Get chat_user_id from staff_id or student_id
     * 
     * @param int $user_id The staff_id or student_id
     * @param string $user_type 'staff' or 'student'
     * @return int|null The chat_user_id or null if not found
     */
    public function getChatUserId($user_id, $user_type = 'staff')
    {
        $user_id = intval($user_id);
        $user_type = strtolower(trim($user_type));

        if ($user_type == 'staff') {
            $this->db->select('id');
            $this->db->from('fl_chat_users');
            $this->db->where('staff_id', $user_id);
            $this->db->where('user_type', 'staff');
            $this->db->limit(1);
        } else {
            $this->db->select('id');
            $this->db->from('fl_chat_users');
            $this->db->where('student_id', $user_id);
            $this->db->where('user_type', 'student');
            $this->db->limit(1);
        }

        $query = $this->db->get();
        if ($query && $query->num_rows() > 0) {
            $row = $query->row();
            return intval($row->id);
        }

        return null;
    }

    /**
     * Create a new chat user entry in fl_chat_users table
     * Uses ON DUPLICATE KEY UPDATE to handle existing entries
     * 
     * @param int $user_id The staff_id or student_id
     * @param string $user_type 'staff' or 'student'
     * @return int|null The chat_user_id or null if creation failed
     */
    public function createChatUser($user_id, $user_type = 'staff')
    {
        $user_id = intval($user_id);
        $user_type = strtolower(trim($user_type));

        if (!in_array($user_type, ['staff', 'student'])) {
            return null;
        }

        // Use raw SQL with ON DUPLICATE KEY UPDATE to match websocket_server.php behavior
        if ($user_type == 'staff') {
            $sql = "INSERT INTO fl_chat_users (staff_id, user_type, created_at, updated_at)
                    VALUES (?, 'staff', NOW(), NOW())
                    ON DUPLICATE KEY UPDATE updated_at = NOW()";
            $params = array($user_id);
        } else {
            $sql = "INSERT INTO fl_chat_users (student_id, user_type, created_at, updated_at)
                    VALUES (?, 'student', NOW(), NOW())
                    ON DUPLICATE KEY UPDATE updated_at = NOW()";
            $params = array($user_id);
        }

        // Execute the query
        $this->db->query($sql, $params);

        // Get the chat_user_id (either newly inserted or existing)
        $chat_user_id = $this->getChatUserId($user_id, $user_type);
        
        return $chat_user_id;
    }

}
