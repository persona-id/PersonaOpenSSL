#ifndef OpenSSLShim_h
#define OpenSSLShim_h

#include <PersonaOpenSSL/conf.h>
#include <PersonaOpenSSL/evp.h>
#include <PersonaOpenSSL/err.h>
#include <PersonaOpenSSL/bio.h>
#include <PersonaOpenSSL/x509.h>
#include <PersonaOpenSSL/cms.h>

#undef EVP_PKEY_base_id
static inline int EVP_PKEY_base_id(const EVP_PKEY *key) {
    return EVP_PKEY_get_base_id(key);
}

#undef sk_X509_num
static inline int sk_X509_num(const STACK_OF(X509) *stack) {
    return OPENSSL_sk_num((const OPENSSL_STACK *)stack);
}

#undef sk_X509_value
static inline X509 *sk_X509_value(const STACK_OF(X509) *stack, int index) {
    return (X509 *)OPENSSL_sk_value((const OPENSSL_STACK *)stack, index);
}

#undef SSL_library_init
static inline void SSL_library_init(void) {
    OPENSSL_init_ssl(0, NULL);
}

#undef SSL_load_error_strings
static inline void SSL_load_error_strings(void) {
    OPENSSL_init_ssl(OPENSSL_INIT_LOAD_SSL_STRINGS \
                     | OPENSSL_INIT_LOAD_CRYPTO_STRINGS, NULL);
}

#undef OpenSSL_add_all_ciphers
static inline void OpenSSL_add_all_ciphers(void) {
    OPENSSL_init_crypto(OPENSSL_INIT_ADD_ALL_CIPHERS, NULL);
}

#undef OpenSSL_add_all_digests
static inline void OpenSSL_add_all_digests(void) {
    OPENSSL_init_crypto(OPENSSL_INIT_ADD_ALL_DIGESTS, NULL);
}

#undef OpenSSL_add_all_algorithms
static inline void OpenSSL_add_all_algorithms(void) {
    #ifdef OPENSSL_LOAD_CONF
    OPENSSL_add_all_algorithms_conf();
    #else
    OPENSSL_add_all_algorithms_noconf();
    #endif
}

#endif
