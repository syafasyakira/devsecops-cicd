import pytest
import json
from app import app


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


def test_index_returns_200(client):
    response = client.get("/")
    assert response.status_code == 200


def test_index_contains_app_name(client):
    response = client.get("/")
    assert b"CI/CD Demo App" in response.data


def test_health_returns_200(client):
    response = client.get("/health")
    assert response.status_code == 200


def test_health_returns_ok_status(client):
    response = client.get("/health")
    data = json.loads(response.data)
    assert data["status"] == "ok"


def test_health_returns_hostname(client):
    response = client.get("/health")
    data = json.loads(response.data)
    assert "hostname" in data
    assert len(data["hostname"]) > 0


def test_info_endpoint(client):
    response = client.get("/info")
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data["app"] == "webapp-cicd"
    assert "version" in data
    assert "build_number" in data
