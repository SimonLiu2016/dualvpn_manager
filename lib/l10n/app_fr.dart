/// French localization resources
class AppLocalizationsFr {
  static const Map<String, String> localizedValues = {
    // Interface principale
    'app_title': 'Gestionnaire DualVPN',
    'home_tab': 'Accueil',
    'config_tab': 'Sources de proxy',
    'proxy_list_tab': 'Liste des proxys',
    'routing_tab': 'Routage',
    'settings_tab': 'Paramètres',

    // Interface des paramètres
    'settings_title': 'Paramètres',
    'language_setting': 'Internationalisation',
    'language_subtitle': 'Paramètres de langue et support multilingue',
    'theme_setting': 'Paramètres du thème',
    'theme_subtitle': 'Options de thème : mode clair, mode sombre, etc.',
    'log_management_setting': 'Gestion des journaux',
    'log_management_subtitle':
        'Configurer la taille des fichiers journaux et le temps de rétention',
    'import_export_setting': 'Import/Export de config',
    'import_export_subtitle':
        'Sauvegarder et restaurer les fichiers de configuration',
    'help_setting': 'Aide',
    'help_subtitle': 'Guide utilisateur et FAQ',
    'copyright_setting': 'Informations de copyright',
    'copyright_subtitle': 'Version du logiciel et informations de licence',
    'failed_to_get_version_info':
        'Échec de l\'obtention des informations de version',
    'no_version_info': 'Aucune information de version',
    'import_export_feature_pending':
        'Fonction d\'import/export en attente de mise en œuvre',
    'select_theme_mode': 'Sélectionnez le mode du thème :',

    // Boîte de dialogue des paramètres du thème
    'theme_dialog_title': 'Paramètres du thème',
    'theme_light': 'Mode clair',
    'theme_dark': 'Mode sombre',
    'theme_system': 'Suivre le système',
    'theme_cancel': 'Annuler',

    // Boîte de dialogue des paramètres de langue
    'language_dialog_title': 'Paramètres de langue',
    'language_select': 'Sélectionnez la langue d\'affichage :',
    'language_chinese': '简体中文',
    'language_english': 'English',
    'language_save_hint':
        'Paramètre de langue enregistré. Redémarrez l\'application pour appliquer les changements.',

    // Boîte de dialogue d'aide
    'help_dialog_title': 'Aide',
    'help_guide': 'Guide utilisateur',
    'help_guide_1':
        '1. Accueil : Affiche l\'état de connexion actuel et les informations du proxy',
    'help_guide_2':
        '2. Sources de proxy : Gère les configurations du serveur proxy',
    'help_guide_3':
        '3. Liste des proxys : Affiche et sélectionne les proxys disponibles',
    'help_guide_4': '4. Routage : Configure les règles de routage du trafic',
    'help_guide_5':
        '5. Paramètres : Configuration et informations de l\'application',
    'help_faq': 'FAQ',
    'help_faq_q1': 'Q : Comment ajouter un nouveau serveur proxy ?',
    'help_faq_a1':
        'R : Cliquez sur le bouton "+" dans la page "Sources de proxy", sélectionnez le fichier de configuration correspondant ou entrez manuellement les informations du serveur.',
    'help_faq_q2': 'Q : Comment changer de proxy ?',
    'help_faq_a2':
        'R : Sélectionnez le proxy souhaité dans la page "Liste des proxys" et cliquez sur le bouton de connexion.',
    'help_faq_q3': 'Q : Comment configurer les règles de routage ?',
    'help_faq_a3':
        'R : Des règles personnalisées peuvent être ajoutées dans la page "Routage" pour contrôler le trafic à travers différents proxys.',
    'help_support': 'Support technique',
    'help_contact':
        'Pour toute autre question, veuillez contacter : 582883825@qq.com',
    'help_confirm': 'OK',

    // Boîte de dialogue des informations de copyright
    'copyright_dialog_title': 'Informations de copyright',
    'copyright_app_name': 'Gestionnaire Dualvpn',
    'copyright_version': 'Version',
    'copyright_author': 'Auteur : Simon',
    'copyright_email': 'Email : 582883825@qq.com',
    'copyright_website': 'Site web : www.v8en.com',
    'copyright_rights': 'Copyright © 2025 Simon',
    'copyright_reserved': 'Tous droits réservés',

    // Interface de la liste des proxys
    'proxy_list_title': 'Liste des proxys',
    'proxy_source_label': 'Sélectionner la source du proxy',
    'refresh_all_latency': 'Actualiser toutes les latences',
    'no_proxy_info': 'Aucune information de proxy',
    'ensure_proxy_configured':
        'Veuillez vous assurer que le proxy est connecté et configuré',
    'proxy_type_not_supported':
        'Ce type de proxy ne prend pas en charge la liste des proxys',
    'proxy_type_direct_connection':
        'Ce type de proxy se connectera directement en utilisant la configuration',
    'type': 'Type',
    'server': 'Serveur',
    'protocol': 'Protocole',
    'latency': 'Latence',
    'not_tested': 'Non testé',
    'testing': 'Test en cours...',
    'connection_failed': 'Échec de la connexion',
    'test_latency': 'Tester la latence',
    'all_proxies_latency_test_completed':
        'Test de latence de tous les proxys terminé',

    // Interface de routage
    'routing_title': 'Configuration du routage',
    'routing_rules': 'Règles de routage',
    'add_rule': 'Ajouter une règle',
    'edit_rule': 'Modifier la règle',
    'delete_rule': 'Supprimer la règle',
    'specify_proxy_source_for_domain':
        'Spécifier la source du proxy pour un domaine spécifique',
    'load_config_failed': 'Échec du chargement de la configuration',
    'enter_domain_example_google_com':
        'Entrez le domaine, par exemple : google.com',
    'select_proxy_source': 'Sélectionner la source du proxy',
    'routing_screen_rule_added': 'Règle de routage ajoutée',

    // Interface de gestion des règles de routage
    'routing_rules_management': 'Gestion des règles de routage',
    'add_new_routing_rule': 'Ajouter une nouvelle règle de routage',
    'website_or_ip_pattern': 'Modèle d\'adresse Web ou IP',
    'example_google_com_or_8_8_8_8': 'Exemple : google.com ou 8.8.8.8',
    'select_vpn_config': 'Sélectionner la configuration VPN',
    'force_use_vpn_type': 'Forcer l\'utilisation du type VPN',
    'enable_rule': 'Activer la règle',
    'add_routing_rule': 'Ajouter une règle de routage',
    'existing_routing_rules': 'Règles de routage existantes',
    'no_vpn_config_please_add_config':
        'Aucune configuration VPN, veuillez d\'abord ajouter une configuration',
    'no_routing_rules': 'Aucune règle de routage',
    'proxy_source': 'Source du proxy',
    'please_fill_complete_info': 'Veuillez remplir toutes les informations',
    'routing_rule_added': 'Règle de routage ajoutée',
    'routing_rule_deleted': 'Règle de routage supprimée',
    'force_use_openvpn': 'Forcer l\'utilisation d\'OpenVPN',
    'force_use_clash': 'Forcer l\'utilisation de Clash',
    'force_use_shadowsocks': 'Forcer l\'utilisation de Shadowsocks',
    'force_use_v2ray': 'Forcer l\'utilisation de V2Ray',
    'force_use_http_proxy': 'Forcer l\'utilisation du proxy HTTP',
    'force_use_socks5_proxy': 'Forcer l\'utilisation du proxy SOCKS5',
    'force_use_custom_proxy': 'Forcer l\'utilisation du proxy personnalisé',
    'config_not_found': 'Configuration non trouvée',
    'vpn_type_openvpn': 'OpenVPN',
    'vpn_type_clash': 'Clash',
    'vpn_type_shadowsocks': 'Shadowsocks',
    'vpn_type_v2ray': 'V2Ray',
    'vpn_type_http_proxy': 'Proxy HTTP',
    'vpn_type_socks5_proxy': 'Proxy SOCKS5',
    'vpn_type_custom_proxy': 'Proxy personnalisé',
    // Interface de gestion de configuration
    'config_title': 'Gestion de configuration',
    'add_config': 'Ajouter une configuration',
    'edit_config': 'Modifier la configuration',
    'delete_config': 'Supprimer la configuration',
    'enable_config': 'Activer la configuration',
    'config': 'Configuration',
    'path': 'Chemin',
    'status': 'Statut',
    'enabled': 'Activé',
    'disabled': 'Désactivé',
    'reload_config': 'Recharger la configuration',
    'update_subscription': 'Mettre à jour l\'abonnement',
    'please_fill_config_name': 'Veuillez remplir le nom de la configuration',
    'please_fill_config_path_or_subscription':
        'Veuillez remplir le chemin de configuration ou le lien d\'abonnement',
    'please_fill_server_address_and_port':
        'Veuillez remplir l\'adresse du serveur et le port',
    'config_added': 'Configuration ajoutée',
    'config_deleted': 'Configuration supprimée',
    'latency_test_completed': 'Test de latence terminé',
    'reloading_openvpn_config': 'Rechargement de la configuration OpenVPN...',
    'openvpn_config_reload_success':
        'Rechargement de la configuration OpenVPN réussi',
    'openvpn_config_reload_failed':
        'Échec du rechargement de la configuration OpenVPN',
    'config_type_not_support_subscription':
        'Ce type de configuration ne prend pas en charge les mises à jour d\'abonnement',
    'config_not_subscription_link':
        'La configuration n\'est pas un lien d\'abonnement',
    'updating_subscription': 'Mise à jour de l\'abonnement...',
    'subscription_update_success': 'Mise à jour de l\'abonnement réussie',
    'subscription_update_failed': 'Échec de la mise à jour de l\'abonnement',
    'subscription_update_failed_check_network':
        'Échec de la mise à jour de l\'abonnement, veuillez vérifier la connexion réseau et le lien d\'abonnement',
    'network_connection_error':
        'Erreur de connexion réseau, veuillez vérifier la connexion',
    'ssl_certificate_error':
        'Erreur de certificat SSL, veuillez vérifier le certificat du serveur',
    'tls_handshake_failed':
        'Échec de la poignée de main TLS, veuillez vérifier la configuration du serveur',
    'subscription_link_not_exist':
        'Le lien d\'abonnement n\'existe pas, veuillez vérifier si le lien est correct',
    'connection_timeout':
        'Délai de connexion dépassé, veuillez réessayer plus tard',
    'config_format_error':
        'Erreur de format de configuration, veuillez vérifier le contenu du lien d\'abonnement',
    'config_content_invalid':
        'Contenu de configuration invalide, veuillez vérifier le contenu du lien d\'abonnement',
    'access_denied':
        'Accès refusé, veuillez vérifier les autorisations du lien d\'abonnement',
    'config_updated': 'Configuration mise à jour',

    // Interface de gestion des sources de proxy
    'add_new_proxy_source': 'Ajouter une nouvelle source de proxy',
    'proxy_source_name': 'Nom de la source du proxy',
    'proxy_type': 'Type de proxy',
    'openvpn_config_file': 'OpenVPN (.ovpn/.conf/.tblk)',
    'clash_config_subscription': 'Clash (Fichier de config/Lien d\'abonnement)',
    'shadowsocks_config_subscription':
        'Shadowsocks (Fichier de config/Lien d\'abonnement)',
    'shadowsocks': 'Shadowsocks',
    'v2ray_config_subscription': 'V2Ray (Fichier de config/Lien d\'abonnement)',
    'v2ray': 'V2Ray',
    'http_proxy': 'Proxy HTTP',
    'socks5_proxy': 'Proxy SOCKS5',
    'custom_proxy': 'Proxy personnalisé',
    'config_file_path': 'Chemin du fichier de configuration',
    'config_file_path_or_subscription':
        'Chemin du fichier de config ou Lien d\'abonnement',
    'username_optional': 'Nom d\'utilisateur (Optionnel)',
    'password_optional': 'Mot de passe (Optionnel)',
    'server_address': 'Adresse du serveur',
    'port': 'Port',
    'add_proxy_source': 'Ajouter une source de proxy',
    'proxy_source_list': 'Liste des sources de proxy',
    'edit_proxy_source': 'Modifier la source du proxy',
    'cancel': 'Annuler',
    'save': 'Enregistrer',

    // Interface d'accueil
    'connection_status': 'État de la connexion',
    'usage_instructions': 'Instructions d\'utilisation :',
    'instruction_1':
        '1. Ajoutez et activez les configurations de proxy dans la page "Sources de proxy"',
    'instruction_2':
        '2. Sélectionnez des serveurs proxy spécifiques dans la page "Liste des proxys"',
    'instruction_3':
        '3. Affichez les sources de proxy activées et les proxys sélectionnés sur cette page',
    'enabled_proxy_sources': 'Sources de proxy activées',
    'selected_proxies': 'Proxys sélectionnés',
    'go_proxy_core': 'Noyau proxy Go',
    'no_enabled_proxy_sources': 'Aucune source de proxy activée',
    'openvpn_label': 'OpenVPN:',
    'clash_label': 'Clash:',
    'shadowsocks_label': 'Shadowsocks:',
    'v2ray_label': 'V2Ray:',
    'http_proxy_label': 'Proxy HTTP:',
    'socks5_proxy_label': 'Proxy SOCKS5:',
    'starting': 'Démarrage',
    'start': 'Démarrer',
    'stop': 'Arrêter',
    'go_proxy_core_stopped': 'Noyau proxy Go arrêté',
    'go_proxy_core_started': 'Noyau proxy Go démarré avec succès',
    'go_proxy_core_start_failed': 'Échec du démarrage du noyau proxy Go',
    'no_selected_proxies': 'Aucun proxy sélectionné',
    'connected': 'Connecté',
    'unknown': 'Inconnu',
  };
}
