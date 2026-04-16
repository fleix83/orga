<template>
  <div class="login-page">
    <form class="login-form" @submit.prevent="login">
      <h1>Orga-Tool</h1>
      <div class="form-group">
        <label>Benutzername</label>
        <input v-model="username" type="text" required autofocus>
      </div>
      <div class="form-group">
        <label>Passwort</label>
        <input v-model="password" type="password" required>
      </div>
      <p v-if="error" class="error">{{ error }}</p>
      <button class="btn btn-primary" type="submit" style="width:100%">Anmelden</button>
    </form>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { api } from '../api.js'

const router = useRouter()
const username = ref('')
const password = ref('')
const error = ref('')

async function login() {
  error.value = ''
  try {
    await api.post('auth.php', { username: username.value, password: password.value })
    router.push('/')
  } catch (e) {
    error.value = e.message
  }
}
</script>

<style scoped>
.login-page { display: flex; align-items: center; justify-content: center; min-height: 100vh; }
.login-form { width: 320px; }
.login-form h1 { font-size: 22px; margin-bottom: 24px; }
.error { color: #dc2626; font-size: 13px; margin-bottom: 12px; }
</style>
