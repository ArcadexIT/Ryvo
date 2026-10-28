import {
  Home,
  Car,
  List,
  BadgeCheck,
  Truck,
  Radio,
  Wallet,
  CreditCard,
  TrendingUp,
  Banknote,
  Tag,
  Percent,
  Ticket,
  HelpCircle,
  Image,
  Settings,
  Shield,
  ClipboardList,
  Receipt,
  ScrollText,
  Scale,
  Star,
  Users,
  Bell,
  KeyRound,
  Globe,
  MapPin,
  type LucideIcon,
} from 'lucide-react';

export interface NavItem {
  label: string;
  href: string;
  icon: LucideIcon;
  badge?: number;
  keywords?: string[];
  module?: string;
}

export interface NavGroup {
  title: string;
  items: NavItem[];
}

export const navigation: NavGroup[] = [
  {
    title: '',
    items: [
      { label: 'Overview', href: '/', icon: Home, keywords: ['home', 'dashboard', 'overview', 'metrics'], module: 'dashboard' },
      { label: 'Live map', href: '/live', icon: Radio, keywords: ['map', 'realtime', 'tracking', 'live ops'], module: 'live' },
      { label: 'Dispatch', href: '/dispatch', icon: List, keywords: ['dispatch', 'assign', 'sla', 'board'], module: 'dispatch' },
      { label: 'Trips', href: '/jobs', icon: Car, keywords: ['rides', 'trips', 'jobs'], module: 'jobs' },
    ],
  },
  {
    title: 'People',
    items: [
      { label: 'Riders', href: '/customers', icon: Users, keywords: ['riders', 'customers', 'users', 'profiles'], module: 'customers' },
      { label: 'Drivers', href: '/providers', icon: Truck, keywords: ['drivers', 'partners', 'providers'], module: 'providers' },
      { label: 'Verification', href: '/providers/kyc', icon: BadgeCheck, keywords: ['verification', 'documents', 'licence', 'kyc'], module: 'kyc' },
      { label: 'Reviews', href: '/reviews', icon: Star, keywords: ['ratings', 'feedback'], module: 'reviews' },
    ],
  },
  {
    title: 'Money',
    items: [
      { label: 'Payments', href: '/finance/payments', icon: CreditCard, keywords: ['transactions'], module: 'finance' },
      { label: 'Wallets', href: '/finance/wallets', icon: Wallet, keywords: ['balance'], module: 'finance' },
      { label: 'Earnings', href: '/finance/earnings', icon: TrendingUp, keywords: ['revenue'], module: 'finance' },
      { label: 'Payouts', href: '/finance/payouts', icon: Banknote, keywords: ['withdraw'], module: 'finance' },
      { label: 'Invoices', href: '/finance/invoices', icon: Receipt, keywords: ['billing', 'invoice'], module: 'finance' },
    ],
  },
  {
    title: 'Pricing',
    items: [
      { label: 'Ride types', href: '/pricing/services', icon: Tag, keywords: ['categories', 'classes'], module: 'pricing' },
      { label: 'Fare rules', href: '/pricing/rules', icon: Percent, keywords: ['fare', 'pricing', 'rules'], module: 'pricing' },
      { label: 'Promo codes', href: '/pricing/promos', icon: Ticket, keywords: ['coupons', 'discounts', 'promos'], module: 'pricing' },
      { label: 'Driver plans', href: '/pricing/subscriptions', icon: CreditCard, keywords: ['subscription', 'daily', 'weekly', 'monthly'], module: 'pricing' },
    ],
  },
  {
    title: 'Content',
    items: [
      { label: 'Tickets', href: '/support', icon: HelpCircle, keywords: ['help', 'tickets', 'support'], module: 'support' },
      { label: 'Broadcasts', href: '/notifications', icon: Bell, keywords: ['broadcast', 'push', 'notifications'], module: 'notifications' },
      { label: 'Banners', href: '/cms/banners', icon: Image, keywords: ['promotions'], module: 'cms' },
      { label: 'FAQs', href: '/cms/faqs', icon: ClipboardList, keywords: ['questions'], module: 'cms' },
      { label: 'Legal', href: '/cms/legal', icon: Scale, keywords: ['terms', 'privacy', 'policy'], module: 'cms' },
    ],
  },
  {
    title: 'Platform',
    items: [
      { label: 'Settings', href: '/settings', icon: Settings, keywords: ['config', 'integrations'], module: 'settings' },
      { label: 'Countries', href: '/settings/countries', icon: Globe, keywords: ['country', 'dial code', 'phone'], module: 'countries' },
      { label: 'Team', href: '/admins', icon: Shield, keywords: ['users', 'roles', 'admins'], module: 'admins' },
      { label: 'Access', href: '/roles', icon: KeyRound, keywords: ['permissions', 'rbac', 'roles'], module: 'roles' },
      { label: 'Audit', href: '/audit', icon: ClipboardList, keywords: ['history', 'actions', 'audit log'], module: 'audit' },
      { label: 'Coverage', href: '/ops/coverage', icon: MapPin, keywords: ['zones', 'area'], module: 'settings' },
      { label: 'Agreements', href: '/ops/agreements', icon: ScrollText, keywords: ['tax', 'insurance'], module: 'settings' },
    ],
  },
];

export const allNavItems = navigation.flatMap((g) => g.items);

export const routeLabels: Record<string, string> = {
  '': 'Overview',
  live: 'Live map',
  dispatch: 'Dispatch',
  customers: 'Riders',
  providers: 'Drivers',
  kyc: 'Verification',
  jobs: 'Trips',
  finance: 'Money',
  payments: 'Payments',
  wallets: 'Wallets',
  earnings: 'Earnings',
  payouts: 'Payouts',
  invoices: 'Invoices',
  ops: 'Platform',
  coverage: 'Coverage',
  training: 'Training',
  agreements: 'Agreements',
  pricing: 'Pricing',
  services: 'Ride types',
  rules: 'Fare rules',
  promos: 'Promo codes',
  support: 'Tickets',
  reviews: 'Reviews',
  notifications: 'Broadcasts',
  cms: 'Content',
  banners: 'Banners',
  faqs: 'FAQs',
  legal: 'Legal',
  settings: 'Settings',
  countries: 'Countries',
  admins: 'Team',
  roles: 'Access',
  audit: 'Audit',
};
