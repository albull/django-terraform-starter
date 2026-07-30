from django.test import TestCase
from django.urls import reverse


class HealthCheckTest(TestCase):
    def test_healthz_returns_ok(self):
        response = self.client.get(reverse("healthz"))
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["app"], "ok")
        self.assertEqual(body["database"], "ok")


class HomeViewTest(TestCase):
    def test_home_renders(self):
        response = self.client.get(reverse("home"))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "It works.")
